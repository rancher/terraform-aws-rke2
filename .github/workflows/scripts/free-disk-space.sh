#!/usr/bin/env bash
set -e
# This expects to be run in a container with the following volumes mounted:
# /usr/share/dotnet:/host_dotnet
# /usr/local/lib/android:/host_android
# /opt/ghc:/host_ghc
# /opt/hostedtoolcache:/host_toolcache
# /usr/local/.ghcup:/host_ghcup
# /usr/local/share/boost:/host_boost

echo "Disk space before cleanup:"
df -h

sudo rm -rf /host_dotnet
sudo rm -rf /host_android
sudo rm -rf /host_ghc
sudo rm -rf /host_toolcache
sudo rm -rf /host_ghcup
sudo rm -rf /host_boost

echo "Disk space after cleanup:"
df -h
