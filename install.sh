#!/usr/bin/env bash
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "Run as root: sudo ./install.sh"
  exit 1
fi

# Default settings
SRT_PORT=9000
HLS_ROOT=/var/www/sportsabo
HLS_PLAYLIST=index.m3u8
SRT_LATENCY=800
PKT_SIZE=1316
DOMAIN=$(curl -s ifconfig.me || echo "localhost")

mkdir -p "$HLS_ROOT"
chown -R www-data:www-data "$HLS_ROOT"
chmod -R 755 "$HLS_ROOT"

# Placeholder index.html
cat > "$HLS_ROOT/index.html" <<'EOF'
<!doctype html>
<html>
  <head><title>sportsabo HLS</title></head>
  <body>
    <h1>Live Stream</h1>
    <p>Open <a href="index.m3u8">index.m3u8</a> to play the stream.</p>
  </body>
</html>
EOF

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

# Prompt encoder choice
echo -e "\nSelect hardware encoder for streaming:"
echo "1) CPU (libx264)"
echo "2) AMD HEVC (hevc_amf)"
echo "3) NVIDIA H.264/H.265 (nvenc)"
read -rp "Enter number [1-3]: " ENC_CHOICE

case $ENC_CHOICE in
  1) ENCODER="libx264" ;;
  2) ENCODER="hevc_amf" ;;
  3) ENCODER="h264_nvenc" ;;
  *) echo "Invalid choice, defaulting to libx264"; ENCODER="libx264" ;;
esac

# Save environment variables
cat > /etc/srt-to-hls.env <<EOF
SRT_PORT=$SRT_PORT
HLS_ROOT=$HLS_ROOT
HLS_PLAYLIST=$HLS_PLAYLIST
SRT_LATENCY=$SRT_LATENCY
PKT_SIZE=$PKT_SIZE
ENCODER=$ENCODER
DOMAIN=$DOMAIN
EOF

# Install ffmpeg-start.sh
cp ffmpeg-start.sh /usr/local/bin/ffmpeg-start.sh
chmod +x /usr/local/bin/ffmpeg-start.sh

# Install systemd service
cp srt-to-hls.service /etc/systemd/system/srt-to-hls.service
systemctl daemon-reload
systemctl enable --now srt-to-hls.service

# Open ports
if command -v ufw &>/dev/null; then
    ufw allow 9000/tcp
    ufw allow 9000/udp
    ufw allow 80/tcp
    ufw reload
fi

# Show URLs
PUBLIC_IP=$DOMAIN

echo -e "\n🎬 Setup complete! Use the following URLs:"
echo "1️⃣ OBS SRT URL (push stream): srt://$PUBLIC_IP:9000?mode=caller&latency=800&pkt_size=1316"
echo "2️⃣ Public HLS URL (watch stream): http://$PUBLIC_IP/index.m3u8"
