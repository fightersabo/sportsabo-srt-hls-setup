#!/usr/bin/env bash
set -euo pipefail

# Load environment variables
source /etc/srt-to-hls.env

SRT_IN="srt://:${SRT_PORT}?mode=listener&latency=${SRT_LATENCY}&pkt_size=${PKT_SIZE}"

if [ "$ENCODER" = "libx264" ]; then
    ffmpeg -hide_banner -y -i "$SRT_IN" \
      -c:v libx264 -preset veryfast -crf 23 \
      -c:a aac -b:a 128k \
      -f hls -hls_time 2 -hls_list_size 6 -hls_flags delete_segments+program_date_time+append_list \
      -hls_segment_type mpegts -hls_playlist_type event "${HLS_ROOT}/${HLS_PLAYLIST}"
elif [ "$ENCODER" = "hevc_amf" ]; then
    ffmpeg -hide_banner -y -i "$SRT_IN" \
      -c:v hevc_amf -b:v 8M \
      -c:a aac -b:a 128k \
      -f hls -hls_time 2 -hls_list_size 6 -hls_flags delete_segments+program_date_time+append_list \
      -hls_segment_type mpegts -hls_playlist_type event "${HLS_ROOT}/${HLS_PLAYLIST}"
elif [ "$ENCODER" = "h264_nvenc" ]; then
    ffmpeg -hide_banner -y -i "$SRT_IN" \
      -c:v h264_nvenc -b:v 8M \
      -c:a aac -b:a 128k \
      -f hls -hls_time 2 -hls_list_size 6 -hls_flags delete_segments+program_date_time+append_list \
      -hls_segment_type mpegts -hls_playlist_type event "${HLS_ROOT}/${HLS_PLAYLIST}"
else
    echo "Unknown encoder $ENCODER. Exiting."
    exit 1
fi
