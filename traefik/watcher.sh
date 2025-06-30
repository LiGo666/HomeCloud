#!/bin/bash

CONFIG_FILE="/app/dns.env"
HASHFILE="/tmp/env.hash"

# initial hash
if [ -f "$CONFIG_FILE" ]; then
  sha256sum "$CONFIG_FILE" > "$HASHFILE"
fi

echo "[Watcher] Starte Dateiüberwachung für $CONFIG_FILE"

while true; do
  inotifywait -e close_write "$CONFIG_FILE" >/dev/null 2>&1

  NEW_HASH=$(sha256sum "$CONFIG_FILE")
  OLD_HASH=$(cat "$HASHFILE")

  if [ "$NEW_HASH" != "$OLD_HASH" ]; then
    echo "[Watcher] Änderung erkannt. Führe DNS-Update aus..."
    cp "$CONFIG_FILE" /app/dns.env.live
    /usr/bin/env $(cat /app/dns.env.live | grep -v '^#' | xargs) /app/update-dns.sh
    echo "$NEW_HASH" > "$HASHFILE"
  else
    echo "[Watcher] Datei gespeichert, aber inhaltlich gleich – kein Update."
  fi
done
