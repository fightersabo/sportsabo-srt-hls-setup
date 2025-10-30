#!/usr/bin/env bash
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
export ENCODER
echo "Selected encoder: $ENCODER"


# Install FFmpeg start script
cat > ffmpeg-start.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail


SRT_IN="srt://:${SRT_PORT}?mode=listener&latency=${SRT_LATENCY}&pkt_size=${PKT_SIZE}"


if [ "$ENCODER" = "libx264" ]; then
ffmpeg -hide_banner -y -i "$SRT_IN" \
-c:v libx264 -preset veryfast -crf 23 \
-c:a aac -b:a 128k \
-f hls -hls_time 2 -hls_list_size 6 -hls_flags delete_segments+program_date_time+append_list \
-hls_segment_type mpegts -hls_playlist_type event "${HLS_ROOT}/${HLS_PLAYLIST}"
else
ffmpeg -hide_banner -y -i "$SRT_IN" \
-c:v "$ENCODER" -b:v 8M \
-c:a aac -b:a 128k \
-f hls -hls_time 2 -hls_list_size 6 -hls_flags delete_segments+program_date_time+append_list \
-hls_segment_type mpegts -hls_playlist_type event "${HLS_ROOT}/${HLS_PLAYLIST}"
fi
EOF


chmod +x ffmpeg-start.sh
install -m 755 ffmpeg-start.sh /usr/local/bin/ffmpeg-start.sh


# Register systemd unit
cat > srt-to-hls.service <<'EOF'
[Unit]
Description=SRT to HLS (FFmpeg)
After=network.target


[Service]
User=www-data
WorkingDirectory=/root
Environment=SRT_PORT=%SRT_PORT% HLS_ROOT=%HLS_ROOT% HLS_PLAYLIST=%HLS_PLAYLIST% SRT_LATENCY=%SRT_LATENCY% PKT_SIZE=%PKT_SIZE% ENCODER=%ENCODER%
ExecStart=/usr/local/bin/ffmpeg-start.sh
Restart=always
RestartSec=5
LimitNOFILE=65536


[Install]
WantedBy=multi-user.target
EOF


install -m 644 srt-to-hls.service /etc/systemd/system/srt-to-hls.service
systemctl daemon-reload
systemctl enable --now srt-to-hls.service


# Open ports in UFW
if command -v ufw &>/dev/null; then
echo "🔥 Opening ports 9000 (SRT) and 80 (HLS) in UFW..."
ufw allow 9000/tcp
ufw allow 9000/udp
ufw allow 80/tcp
ufw reload
fi


# Show URLs
PUBLIC_IP=$(curl -s ifconfig.me || echo "<your-public-ip>")


echo ""
echo "🎬 Setup complete! Use the following URLs:"
echo ""
echo "1️⃣ OBS SRT URL (push stream):"
echo " srt://${PUBLIC_IP}:9000?mode=caller&latency=800&pkt_size=1316"
echo ""
echo "2️⃣ Public HLS URL (watch stream):"
echo " http://${PUBLIC_IP}/index.m3u8"
echo ""
echo "Open the HLS URL in VLC, Safari, or any HLS-compatible player."
