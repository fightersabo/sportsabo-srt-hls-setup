#!/usr/bin/env bash
set -euo pipefail


if [[ $EUID -ne 0 ]]; then
echo "Run as root: sudo ./install.sh"
exit 1
fi


# Prompt for DuckDNS info
read -p "Enter your DuckDNS domain (e.g., sportsabo.duckdns.org): " DOMAIN
read -p "Enter your DuckDNS token: " DUCKDNS_TOKEN


# Default settings
SRT_PORT=9000
HLS_ROOT=/var/www/sportsabo
HLS_PLAYLIST=index.m3u8
SRT_LATENCY=800
PKT_SIZE=1316
USE_GPU=false # true if AMD GPU + hevc_amf


export DOMAIN DUCKDNS_TOKEN SRT_PORT HLS_ROOT HLS_PLAYLIST SRT_LATENCY PKT_SIZE USE_GPU


# Install dependencies
apt update
apt install -y ffmpeg nginx certbot python3-certbot-nginx curl


# Create HLS folder
mkdir -p "$HLS_ROOT"
chown -R www-data:www-data "$HLS_ROOT"
chmod -R 755 "$HLS_ROOT"


# Copy example index
cp -n www/index.html "$HLS_ROOT/index.html"


# Nginx site config
cat > /etc/nginx/sites-available/sportsabo <<'NGCONF'
server {
listen 80;
server_name _;


root /var/www/sportsabo;
index index.html;


location / {
types {
application/vnd.apple.mpegurl m3u8;
video/mp2t ts;
}
add_header Cache-Control no-cache;
add_header Access-Control-Allow-Origin *;
}
}
NGCONF


ln -sf /etc/nginx/sites-available/sportsabo /etc/nginx/sites-enabled/sportsabo
rm -f /etc/nginx/sites-enabled/default
systemctl restart nginx


# Install scripts
install -m 700 duck.sh /usr/local/bin/duck.sh
install -m 755 ffmpeg-start.sh /usr/local/bin/ffmpeg-start.sh


# Register systemd units
install -m 644 srt-to-hls.service /etc/systemd/system/srt-to-hls.service
install -m 644 duckdns.service /etc/systemd/system/duckdns.service
install -m 644 duckdns.timer /etc/systemd/system/duckdns.timer


systemctl daemon-reload
systemctl enable --now duckdns.timer
systemctl enable --now srt-to-hls.service


# Attempt SSL
if curl -s --head "http://$DOMAIN/" | head -n 1 | grep -q "200"; then
echo "Attempting to obtain Let's Encrypt certificate for $DOMAIN"
certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos -m "admin@$DOMAIN" || echo "certbot failed"
systemctl reload nginx || true
else
echo "Domain does not resolve yet. You can run certbot later."
fi


echo "Installation completed. Your public HLS stream will be at http://$DOMAIN/${HLS_PLAYLIST}"
