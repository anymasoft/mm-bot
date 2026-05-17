#!/bin/bash
source ~/miniconda3/etc/profile.d/conda.sh
conda activate hummingbot
cd ~/projects/hummingbot
# Send exit immediately; capture first 30 lines of CLI startup
echo "=== CLI startup (auto-exit) ==="
timeout 15 bash -c "printf 'exit\n' | python bin/hummingbot.py 2>&1 | head -40" || echo "(timeout reached, CLI was running)"
echo "=== CLI smoke test done ==="
