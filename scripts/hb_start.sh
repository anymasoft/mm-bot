#!/bin/bash
# Start Hummingbot CLI in interactive mode.
# Usage: bash /mnt/c/BUFFER/mm-bot/scripts/hb_start.sh
# Inside WSL: bash ~/projects/trading-bot/scripts/hb_start.sh (if symlinked)
set -e

source ~/miniconda3/etc/profile.d/conda.sh
conda activate hummingbot
cd ~/projects/hummingbot
exec python bin/hummingbot.py "$@"
