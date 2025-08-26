#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$SCRIPT_DIR/../arch/arm64/configs"
cp "$CONFIG_DIR/nethunter_defconfig_apollo" "$CONFIG_DIR/nethunter_defconfig";
git switch alioth;
sudo ./build.sh
