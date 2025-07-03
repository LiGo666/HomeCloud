#!/bin/bash

# Logging configuration - using standard output for docker logs
LOG_PREFIX="[Route53-Updater]"
NS_SERVER="8.8.8.8"
DNS_ENV_FILE="/app/dns.env"
AWS_ENV_FILE="/app/aws.env"
DEBUG=false

# Timestamped log function for stdout (docker logs)
log() {
  echo "$LOG_PREFIX [$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Debug log function that only prints if DEBUG=true
debug_log() {
  if [ "$DEBUG" = true ]; then
    echo "$LOG_PREFIX [DEBUG] [$(date '+%Y-%m-%d %H:%M:%S')] $1"
  fi
}

# Source DNS environment file
if [ -f "$DNS_ENV_FILE" ]; then
  debug_log "Loading DNS configuration from $DNS_ENV_FILE"
  source "$DNS_ENV_FILE"
else
  debug_log "WARNING: DNS environment file $DNS_ENV_FILE not found"
  # Try to find it in the current directory
  if [ -f "./dns.env" ]; then
    debug_log "Loading DNS configuration from ./dns.env"
    source "./dns.env"
  fi
fi



# Load AWS credentials from Docker secrets
if [ -f "/run/secrets/AWS_CREDENTIALS" ]; then
  debug_log "Loading AWS credentials from Docker secrets"
  source /run/secrets/AWS_CREDENTIALS
fi

# Verify AWS credentials are loaded
if [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
  ERROR_MSG="AWS credentials not found. Ensure they are set as environment variables or in /run/secrets/AWS_CREDENTIALS"
  log "ERROR: $ERROR_MSG"
  exit 1
fi


# Debug AWS credentials (without showing secret)
debug_log "Using AWS credentials: AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID:0:5}... AWS_REGION=${AWS_REGION}"

# Variablen aus Umgebungsvariablen
# Verbesserte IP-Erkennung mit mehreren Fallback-Quellen
get_public_ip() {
  # Versuche mehrere Dienste zur IP-Erkennung mit Timeout
  local ip
  
  # Versuch 1: Amazon
  ip=$(curl -s --connect-timeout 5 https://checkip.amazonaws.com)
  if [[ -n "$ip" && "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "$ip"
    return 0
  fi
  
  # Versuch 2: ipify.org
  ip=$(curl -s --connect-timeout 5 https://api.ipify.org)
  if [[ -n "$ip" && "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "$ip"
    return 0
  fi
  
  # Versuch 3: ifconfig.me
  ip=$(curl -s --connect-timeout 5 https://ifconfig.me)
  if [[ -n "$ip" && "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "$ip"
    return 0
  fi
  
  # Versuch 4: icanhazip.com
  ip=$(curl -s --connect-timeout 5 https://icanhazip.com)
  if [[ -n "$ip" && "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "$ip"
    return 0
  fi
  
  # Versuch 5: myexternalip.com
  ip=$(curl -s --connect-timeout 5 https://myexternalip.com/raw)
  if [[ -n "$ip" && "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "$ip"
    return 0
  fi
  
  # Versuch 6: DNS-Lookup der aktuellen Domain als Fallback
  # Wenn eine der Domains bereits existiert, verwenden wir deren IP
  if [ -n "$SUBDOMAINS" ] && [ -n "$ROOT_DOMAIN" ]; then
    IFS=',' read -ra HOSTS <<< "$SUBDOMAINS"
    for SUB in "${HOSTS[@]}"; do
      HOST="$SUB.$ROOT_DOMAIN"
      ip=$(dig +short "$HOST" @"$NS_SERVER" | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -n1)
      if [[ -n "$ip" && "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        log "Using existing IP from $HOST as fallback: $ip"
        echo "$ip"
        return 0
      fi
    done
  fi
  
  # Versuch 7: Statische Fallback-IP aus Umgebungsvariable
  if [ -n "$FALLBACK_IP" ]; then
    echo "$FALLBACK_IP"
    echo "$LOG_PREFIX Fallback: Verwende konfigurierte Fallback-IP: $FALLBACK_IP" >&2
    return 0
  fi
  
  # Alle Versuche fehlgeschlagen
  return 1
}

# Validate required variables
ZONE_ID=${ZONE_ID:-""}
ROOT_DOMAIN=${ROOT_DOMAIN:-""}
SUBDOMAINS=${SUBDOMAINS:-""}
TTL=${TTL:-"60"}
FALLBACK_IP=${FALLBACK_IP:-""}

# Check for required variables and set defaults where possible
if [ -z "$ZONE_ID" ]; then
  # Fallback to hardcoded value
  ZONE_ID="Z047500032D8WBNCDIUT7"
  debug_log "Using hardcoded ZONE_ID: $ZONE_ID"
fi

if [ -z "$ROOT_DOMAIN" ]; then
  # Fallback to hardcoded value
  ROOT_DOMAIN="christiangotthardt.de"
  debug_log "Using hardcoded ROOT_DOMAIN: $ROOT_DOMAIN"
fi

if [ -z "$SUBDOMAINS" ]; then
  # Fallback to hardcoded value
  SUBDOMAINS="mmb,upload,wordpress,lighthouse,opencloud"
  debug_log "Using hardcoded SUBDOMAINS: $SUBDOMAINS"
fi

# Debug log final configuration
debug_log "Starting DNS update with configuration:"
debug_log "AWS_REGION: ${AWS_REGION:-not set}, ZONE_ID: $ZONE_ID"
debug_log "ROOT_DOMAIN: $ROOT_DOMAIN, SUBDOMAINS: $SUBDOMAINS"

# Lade Fallback-IP aus Umgebungsvariable oder setze auf leer
FALLBACK_IP=${FALLBACK_IP:-""}

# Versuche, die öffentliche IP zu ermitteln
PUBLIC_IP=$(get_public_ip)

# Wenn keine IP ermittelt werden konnte und keine Fallback-IP konfiguriert ist, beende mit Fehler
if [ -z "$PUBLIC_IP" ] && [ -z "$FALLBACK_IP" ]; then
  log "ERROR: Could not determine public IP and no fallback IP configured"
  log "Please set FALLBACK_IP environment variable to use a static IP as fallback"
  exit 1
fi

# Use FALLBACK_IP if PUBLIC_IP is not available
if [ -z "$PUBLIC_IP" ] && [ -n "$FALLBACK_IP" ]; then
  PUBLIC_IP="$FALLBACK_IP"
  log "Using configured fallback IP: $PUBLIC_IP"
fi

ZONE_ID=${ZONE_ID:-"dein-default-zoneid"}
ROOT_DOMAIN=${ROOT_DOMAIN:-"example.com"}
TTL=${TTL:-"60"}
SUBDOMAINS=${SUBDOMAINS:-""}
MX_HOST=${MX_HOST}
MX_PRIORITY=${MX_PRIORITY:-10}

if [ -z "$PUBLIC_IP" ]; then
  echo "$LOG_PREFIX Fehler: keine öffentliche IP ermittelt."
  exit 1
fi

# Initialize variables for tracking updates
UPDATED_DOMAINS=""
ANY_UPDATES_NEEDED=false

IFS=',' read -ra HOSTS <<< "$SUBDOMAINS"
for SUB in "${HOSTS[@]}"; do
  HOST="$SUB.$ROOT_DOMAIN"
  debug_log "Checking $HOST..."

  CURRENT_IP=$(dig +short "$HOST" @"$NS_SERVER" | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -n1)

  if [ "$CURRENT_IP" == "$PUBLIC_IP" ]; then
    debug_log "No update needed for $HOST - already points to $PUBLIC_IP"
    continue
  fi
  
  debug_log "Updating $HOST from $CURRENT_IP to $PUBLIC_IP"

  cat > /tmp/change-$SUB.json <<EOF
{
  "Comment": "Update A record for $HOST",
  "Changes": [
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "$HOST.",
        "Type": "A",
        "TTL": $TTL,
        "ResourceRecords": [
          { "Value": "$PUBLIC_IP" }
        ]
      }
    }
  ]
}
EOF

  if AWS_ACCESS_KEY_ID="$AWS_ACCESS_KEY_ID" AWS_SECRET_ACCESS_KEY="$AWS_SECRET_ACCESS_KEY" AWS_REGION="$AWS_REGION" \
    aws route53 change-resource-record-sets \
    --hosted-zone-id "$ZONE_ID" \
    --change-batch file:///tmp/change-$SUB.json > /tmp/route53-output.json 2>&1; then
    debug_log "Successfully updated $HOST to $PUBLIC_IP"
    # Add to updated domains list
    UPDATED_DOMAINS="${UPDATED_DOMAINS}${UPDATED_DOMAINS:+,}$SUB"
  else
    ERROR_MSG="Failed to update $HOST: $(cat /tmp/route53-output.json | tr '\n' ' ')"
    debug_log "ERROR: $ERROR_MSG"
    log "ERROR: $ERROR_MSG"
    exit 1
  fi
done

if [ -n "$MX_HOST" ]; then
  # Check current MX record
  debug_log "Checking MX record for $ROOT_DOMAIN"
  CURRENT_MX=$(dig +short MX "$ROOT_DOMAIN" @"$NS_SERVER" | grep -E "^$MX_PRIORITY " | head -n1)
  EXPECTED_MX="$MX_PRIORITY $MX_HOST."
  
  # Compare current and expected MX records
  if [[ "$CURRENT_MX" == "$EXPECTED_MX" ]]; then
    debug_log "No update needed for MX record - already set to '$EXPECTED_MX'"
  else
    debug_log "MX record needs update: Current='$CURRENT_MX', Expected='$EXPECTED_MX'"
    
    cat > /tmp/mx.json <<EOF
{
  "Comment": "Update MX record for $ROOT_DOMAIN",
  "Changes": [
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "$ROOT_DOMAIN.",
        "Type": "MX",
        "TTL": $TTL,
        "ResourceRecords": [
          { "Value": "$MX_PRIORITY $MX_HOST." }
        ]
      }
    }
  ]
}
EOF

    if AWS_ACCESS_KEY_ID="$AWS_ACCESS_KEY_ID" AWS_SECRET_ACCESS_KEY="$AWS_SECRET_ACCESS_KEY" AWS_REGION="$AWS_REGION" \
      aws route53 change-resource-record-sets \
      --hosted-zone-id "$ZONE_ID" \
      --change-batch file:///tmp/mx.json > /tmp/mx-output.json 2>&1; then
      debug_log "Successfully updated MX record to: $MX_PRIORITY $MX_HOST"
      ANY_UPDATES_NEEDED=true
    else
      ERROR_MSG="Failed to update MX record: $(cat /tmp/mx-output.json | tr '\n' ' ')"
      debug_log "ERROR: $ERROR_MSG"
      log "ERROR: $ERROR_MSG"
      exit 1
    fi
  fi
fi

# Print final summary line
if [ -n "$UPDATED_DOMAINS" ]; then
  log "External IP updated ($PUBLIC_IP) for sub-domains $UPDATED_DOMAINS"
elif [ "$ANY_UPDATES_NEEDED" = true ]; then
  log "External IP checked, MX record updated"
else
  log "External IP checked, no change required"
fi
