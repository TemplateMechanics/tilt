#!/usr/bin/env bash
# Helper script to run commands with admin privileges via a GUI or TTY prompt.
# Usage: ./sudo-helper.sh "command to run as admin"
#
# macOS:   pops a native password dialog via osascript (works without TTY)
# Linux:   tries pkexec (GUI), then zenity+sudo, then falls back to sudo
# Windows: not supported (use PowerShell RunAs)
set -euo pipefail

CMD="$1"
OS_TYPE="$(uname -s)"

case "$OS_TYPE" in
    Darwin)
        osascript <<EOF
do shell script "$CMD" with administrator privileges
EOF
        ;;
    Linux)
        if command -v pkexec &>/dev/null; then
            pkexec sh -c "$CMD"
        elif command -v zenity &>/dev/null; then
            PASS=$(zenity --password --title="Admin privileges required" 2>/dev/null) || { echo "Cancelled"; exit 1; }
            echo "$PASS" | sudo -S sh -c "$CMD"
        else
            sudo sh -c "$CMD"
        fi
        ;;
    *)
        echo "Unsupported OS: $OS_TYPE — falling back to sudo"
        sudo sh -c "$CMD"
        ;;
esac
