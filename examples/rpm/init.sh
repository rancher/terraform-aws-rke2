#!/bin/env bash
set -x
set -e
# this script will update the server before install
dnf update -y

# reboot in 2 seconds and exit this script
# this allows us to reboot without Terraform receiving errors
# WARNING: there is careful timing here, the reboot must happen before Terraform reconnects for the next script, but give enough time for cloud-init to finish
( sleep 1 ; reboot ) & 
exit 0