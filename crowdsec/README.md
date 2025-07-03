# CrowdSec GeoIP Database

Download the MaxMind GeoLite2 City database and save it here as `GeoLite2-City.mmdb` (binary).

1. Create a free MaxMind account: https://www.maxmind.com/en/geolite2/signup
2. Generate a license key, then download the compressed DB:

```bash
curl -L --compressed "https://download.maxmind.com/app/geoip_download?edition_id=GeoLite2-City&license_key=<LICENSE_KEY>&suffix=tar.gz" -o GeoLite2-City.tar.gz
mkdir tmp && tar -xzf GeoLite2-City.tar.gz -C tmp --strip-components=1
mv tmp/GeoLite2-City.mmdb GeoLite2-City.mmdb
rm -r tmp GeoLite2-City.tar.gz
```

3. Re-create/upgrade the `crowdsec` container (`docker compose up -d crowdsec`).

After restart, CrowdSec metrics will include `country_code`, allowing world-map panels in Grafana.
