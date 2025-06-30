#!/bin/sh

ACME_JSON_PATH="/letsencrypt/acme.json"
CERT_DIR="/certs"
DOMAIN="mail.christiangotthardt.de"

mkdir -p "$CERT_DIR"

# Extrahiere Zertifikat und Key aus dem neuen JSON-Format
jq -r --arg domain "$DOMAIN" '.letsencrypt.Certificates[] | select(.domain.main==$domain) | .certificate' "$ACME_JSON_PATH" | base64 -d > "$CERT_DIR/mail.crt"
jq -r --arg domain "$DOMAIN" '.letsencrypt.Certificates[] | select(.domain.main==$domain) | .key' "$ACME_JSON_PATH" | base64 -d > "$CERT_DIR/mail.key"

chmod 600 "$CERT_DIR/mail.key"
chmod 644 "$CERT_DIR/mail.crt"

echo "✅ Zertifikate extrahiert und gespeichert!"
