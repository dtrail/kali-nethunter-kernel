#!/bin/bash

#!/bin/bash

# Get the current branch name
current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)

if [[ "$current_branch" == "rls" ]]; then
    echo "✅ You are on the correct branch: $current_branch"
else
    echo "❌ You are on branch: $current_branch (expected: rls)"
    echo "Switching to rls..."
    git switch rls
    echo "Switched to $current_branch"
    exit 1
fi

pause

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$SCRIPT_DIR/../arch/arm64/configs"
cp "$CONFIG_DIR/nethunter_defconfig_apollo" "$CONFIG_DIR/nethunter_defconfig";

sudo ./build.sh
if [ $? -eq 0 ]; then
    echo "Script completed successfully."
else
    echo "Script failed with exit code $?."
fi
