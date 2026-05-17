#!/bin/bash
ROOT="/mnt/d/DTS"
echo "=== Криптовалюта/Новая папка ==="
ls "$ROOT/Криптовалюта/Новая папка" 2>&1 | head -10
echo
echo "=== sample BTSX folder contents ==="
ls "$ROOT/Криптовалюта/BitsexCoin (BTSX) Биткоин к Доллару США (BTC_USD)" | head -10
echo
echo "=== sample non-BTSX BTC-USD subdir contents ==="
ls "$ROOT/Криптовалюта/Биткоин к доллару (BTC-USD)" | head -10
echo
echo "=== BTSX BTC sample file ==="
f="$(find "$ROOT/Криптовалюта/BitsexCoin (BTSX) Биткоин к Доллару США (BTC_USD)" -type f | head -1)"
echo "file: $f"
head -3 "$f"
echo "..."
tail -2 "$f"
ls -la "$f"
echo
echo "=== Each Криптовалюта subfolder: file count, total size, sample file ==="
for d in "$ROOT/Криптовалюта"/*/; do
  cnt=$(find "$d" -type f | wc -l)
  sz=$(du -sh "$d" | cut -f1)
  sample=$(find "$d" -type f | head -1)
  echo "[$sz, $cnt files] $d"
  if [ -n "$sample" ]; then
    head -1 "$sample"
  fi
done
echo
echo "=== ETF Мосбиржа sample ==="
ls "$ROOT/ETF Мосбиржа/SBMX" 2>&1 | head -5
f=$(find "$ROOT/ETF Мосбиржа/SBMX" -type f | head -1)
echo "file: $f"
head -2 "$f"
tail -2 "$f"
echo
echo "=== Encoding probes ==="
file -i "$ROOT/binance/BTCUSDT_1m_binance.txt"
file -i "$ROOT/Акции/SBER/SBER.txt"
file -i "$ROOT/ТИКИ/SPFB.RTS.txt"
file -i "$ROOT/ТИКИ/Тики_с_2017_по_Март_2021/br_ticks_2021.txt"
echo
echo "=== BTC-USD GDAX coverage check ==="
g="$ROOT/Криптовалюта/Биткоин к доллару (BTC-USD)/GDAX.BTC-USD.txt"
wc -l "$g"
echo "first 2 data rows:"
sed -n '2,3p' "$g"
echo "last 2 rows:"
tail -2 "$g"
echo
echo "=== MOEX FORTS futures sample (Si) ==="
ls "$ROOT/SI" | head -5
f=$(find "$ROOT/SI" -type f | head -1)
echo "file: $f"
head -2 "$f"
tail -2 "$f"
echo
echo "=== RTSM (small RTS) sample ==="
ls "$ROOT/RTSM" | head -5
echo
echo "=== Coverage check on Si (USDRUBF) ==="
f="$ROOT/USDRUBF/USDRUBF.txt"
if [ -f "$f" ]; then
  head -2 "$f"
  tail -2 "$f"
  ls -la "$f"
fi
