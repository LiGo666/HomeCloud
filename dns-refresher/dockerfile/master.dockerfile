FROM debian:bullseye-slim

# --- Systempakete ---
RUN apt-get update && apt-get install -y \
    curl dnsutils awscli inotify-tools cron procps ca-certificates jq \
    iputils-ping net-tools \
 && rm -rf /var/lib/apt/lists/* \
 && update-ca-certificates

# --- Arbeitsverzeichnis & Skripte ---
WORKDIR /app
COPY update-dns.sh watcher.sh /app/
RUN chmod +x /app/*.sh

# --- Cron-Setup ---
RUN echo 'SHELL=/bin/bash' > /etc/cron.d/ip-updater \
    && echo 'PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin' >> /etc/cron.d/ip-updater \
    && echo 'MAILTO=""' >> /etc/cron.d/ip-updater \
    && echo 'AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}' >> /etc/environment \
    && echo 'AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}' >> /etc/environment \
    && echo 'AWS_REGION=${AWS_REGION}' >> /etc/environment \
    && echo 'ROOT_DOMAIN=christiangotthardt.de' >> /etc/environment \
    && echo 'SUBDOMAINS=mmb,upload,wordpress,lighthouse,opencloud' >> /etc/environment \
    && echo 'ZONE_ID=Z047500032D8WBNCDIUT7' >> /etc/environment \
    && echo 'FALLBACK_IP=79.209.3.144' >> /etc/environment \
    && echo 'TTL=60' >> /etc/environment \
    && echo 'MX_HOST=mail2.christiangotthardt.de' >> /etc/environment \
    && echo 'MX_PRIORITY=10' >> /etc/environment \
    && echo 'BASH_ENV=/etc/environment' >> /etc/cron.d/ip-updater \
    && echo '*/5 * * * * root echo "[$(date)] Starting DNS update" >> /var/log/cron.log 2>&1' >> /etc/cron.d/ip-updater \
    && echo '*/5 * * * * root . /etc/environment && /app/update-dns.sh >> /var/log/cron.log 2>&1' >> /etc/cron.d/ip-updater \
    && chmod 0644 /etc/cron.d/ip-updater \
    && touch /var/log/cron.log \
    && chmod 666 /var/log/cron.log

# --- Healthcheck ---
HEALTHCHECK --interval=60s --timeout=10s --start-period=5s --retries=3 \
  CMD curl -s --connect-timeout 5 https://checkip.amazonaws.com || curl -s --connect-timeout 5 https://api.ipify.org || exit 1

# --- Start: cron and watcher ---
CMD bash -c "echo '[System] Container started at $(date)' && \
             echo '[System] Testing network connectivity...' && \
             (curl -s --connect-timeout 5 https://checkip.amazonaws.com || \
              curl -s --connect-timeout 5 https://api.ipify.org || \
              curl -s --connect-timeout 5 https://ifconfig.me || \
              curl -s --connect-timeout 5 https://icanhazip.com) && \
             echo '[System] Network connectivity OK' && \
             echo '[System] Running initial IP update' && \
             /app/update-dns.sh && \
             echo '[System] Starting watcher for config changes' && \
             /app/watcher.sh & \
             echo '[System] Starting cron service for regular IP updates' && \
             cron && \
             tail -f /var/log/cron.log"
