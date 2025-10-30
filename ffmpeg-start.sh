#!/usr/bin/env bash


SRT_IN="srt://:${SRT_PORT}?mode=listener&latency=${SRT_LATENCY}&pkt_size=${PKT_SIZE}"


# Pass-through mode, OBS controls bitrate and encoding
ffmpeg -hide_banner -y -i "$SRT_IN" \
-c copy \
-f hls -hls_time 2 -hls_list_size 6 -hls_flags delete_segments+program_date_time+append_list \
-hls_segment_type mpegts -hls_playlist_type event "${HLS_ROOT}/${HLS_PLAYLIST}"
