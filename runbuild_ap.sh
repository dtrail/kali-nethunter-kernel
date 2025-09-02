#!/bin/bash

# Get the current branch name
current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)

if [[ "$current_branch" == "rls" ]]; then
    echo "✅ You are on the correct branch: $current_branch"
else
    echo "❌ You are on branch: $current_branch (expected: rls)"
    echo "Switching to rls..."
    git switch rls
    if [[ "$current_branch" == "rls" ]]; then
    echo "✅ Switched to correct branch: $current_branch"
    else
    current_branch=$(git rev-parse --abbrev-ref HEAD)
    echo "❌ Nope! Still on branch: $current_branch ... CHECK your damn script!!"
    exit 1
  fi
fi

# Pause for user confirmation
read -n 1 -s -r -p "Branch OK? Continue or break (CTRL+C): "
echo

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$SCRIPT_DIR/../arch/arm64/configs"

cp "$CONFIG_DIR/nethunter_defconfig_apollo" "$CONFIG_DIR/nethunter_defconfig"


### Run the builder ###
sudo ./build.sh
### END ###

cd "$SCRIPT_DIR" || {
    echo "Failed to change directory to $SCRIPT_DIR"
    exit 1
}

echo "Kernel build completed! Checking branch..."

current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)

if [[ "$current_branch" == "rls" ]]; then
    echo "✅ You are on the correct branch: $current_branch"
else
    echo "❌ You are on branch: $current_branch (expected: rls)"
    echo "Something went wrong! You NEED to re-run the build in the correct branch"
    echo "Switching to rls..."
    git switch rls
    current_branch=$(git rev-parse --abbrev-ref HEAD)
    echo "Switched to $current_branch"
fi

read -n 1 -s -r -p "If your branch is not rls, check your shitty script!"
echo

