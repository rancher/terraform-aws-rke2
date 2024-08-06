#!/bin/bash
set -e
INPUTS="$(jq -r '.')"
KEYS="$(jq -r '.|keys|.[]' <<< "$INPUTS")"
for k in $KEYS; do
  eval "$(echo "$INPUTS" | jq -r '@sh "'$k'=\(.'$k')"')"
done

DATA="$(cat "$data" | jq -r '.')"
KEYS="$(jq -r '.|keys|.[]' <<< "$DATA")"
for k in $KEYS; do
  eval "$(echo "$DATA" | jq -r '@sh "'$k'=\(.'$k'.value)"')"
done
# Safely produce a JSON object containing the result value.
# jq will ensure that the value is properly quoted and escaped to produce a valid JSON string.
jq -n --arg kubeconfig "$kubeconfig" --arg api "$api" --arg server_ip "$server_ip" '{"kubeconfig":$kubeconfig,"api":$api,"server_ip",$server_ip}'
