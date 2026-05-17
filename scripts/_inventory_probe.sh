#!/bin/bash
# Discovery probes for D:\DTS quote archive — read-only, no mutations.
set -u

ROOT="/mnt/d/DTS"

echo "=== BIN file probe ==="
BIN_SAMPLE="$ROOT/ТИКИ/RTS 2018/rts-12.18/RTS-12.18.01.03.2018.bin"
file "$BIN_SAMPLE"
ls -la "$BIN_SAMPLE"
echo "--- first 512 bytes hexdump ---"
xxd "$BIN_SAMPLE" | head -32
echo

echo "=== Try second .bin from different futures ==="
BIN2="$(find "$ROOT/ТИКИ/RTS 2018/Rts3.18" -name '*.bin' 2>/dev/null | head -1)"
file "$BIN2"
ls -la "$BIN2"
xxd "$BIN2" | head -10
echo

echo "=== Total .bin size by parent dir ==="
find "$ROOT" -name '*.bin' -printf '%h %s\n' | awk '{a[$1]+=$2} END {for (k in a) print a[k], k}' | sort -rn | head -20
echo

echo "=== Total bytes per top-level dir ==="
for d in "$ROOT"/*/; do
  du -sh "$d" 2>/dev/null
done | sort -h
echo

echo "=== Sample 5 binance files for format consistency ==="
for f in BTCUSDT_1m_binance.txt ETHUSDT_1m_binance.txt BNBUSDT_1m_binance.txt LTCUSDT_1m_binance.txt XRPUSDT_1m_binance.txt; do
  echo "--- $f ---"
  head -2 "$ROOT/binance/$f"
  echo "rows: $(wc -l < "$ROOT/binance/$f"), size: $(stat -c%s "$ROOT/binance/$f")"
done
echo

echo "=== ТИКИ/RTS 2018 subfolder breakdown ==="
for sub in "$ROOT/ТИКИ/RTS 2018"/*/; do
  cnt=$(find "$sub" -name '*.bin' | wc -l)
  sz=$(du -sh "$sub" | cut -f1)
  echo "$sub : $cnt bin files, $sz total"
done
echo

echo "=== ТИКИ flat .txt files ==="
ls -la "$ROOT/ТИКИ/"*.txt 2>/dev/null
echo

echo "=== Тики_с_2017_по_Март_2021 contents ==="
ls -la "$ROOT/ТИКИ/Тики_с_2017_по_Март_2021/"
echo

echo "=== Other top-level interesting folders ==="
for d in "ETF Мосбиржа" Криптовалюта; do
  echo "--- $d ---"
  ls "$ROOT/$d" | head -30
done
