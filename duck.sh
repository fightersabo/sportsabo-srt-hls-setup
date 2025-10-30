#!/usr/bin/env bash
set -e


if [[ -z "$DUCKDNS_TOKEN" || -z "$DOMAIN" ]]; then
echo "DUCKDNS_TOKEN or DOMAIN not set in environment" >&2
exit 1
fi


URL="https://www.duckdns.org/update?domains=${DOMAIN}&token=${DUCKDNS_TOKEN}&ip="
curl -s "$URL" | tee /var/log/duckdns-update.log
