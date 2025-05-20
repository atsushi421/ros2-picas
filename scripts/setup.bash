#!/bin/bash

set -e

CONF_FILE="/etc/ld.so.conf.d/for_cie.conf"
sudo tee "$CONF_FILE" >/dev/null <<EOF
/opt/ros/humble/lib
/opt/ros/humble/lib/x86_64-linux-gnu
/home/atsushi/callback_isolated_executor/install/thread_config_msgs/lib
EOF
sudo ldconfig
