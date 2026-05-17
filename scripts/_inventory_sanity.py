#!/usr/bin/env python3
"""Sanity check для одного файла BTCUSDT 1m, без модификации."""

import os
import sys
from datetime import datetime

PATH = "/mnt/d/DTS/binance/BTCUSDT_1m_binance.txt"
print(f"=== Sanity {PATH} ===")
size = os.path.getsize(PATH)
print(f"size: {size} bytes ({size/1e6:.1f} MB)")

rows = 0
nan_rows = 0
zero_close = 0
neg_vol = 0
ts_prev = None
non_monotonic = 0
dup_ts = 0
seen_ts = set()
first_ts = None
last_ts = None
distinct_dates = set()
header = None
ohlc_violations = 0

with open(PATH, "r", encoding="utf-8", errors="replace") as f:
    for i, line in enumerate(f):
        line = line.rstrip("\n").rstrip("\r")
        if i == 0:
            header = line
            continue
        parts = line.split(",")
        if len(parts) < 9:
            nan_rows += 1
            continue
        ticker, per, date, time_, o, h, l, c, v = parts[:9]
        try:
            ts = datetime.strptime(date + time_, "%Y%m%d%H%M%S")
            o_f, h_f, l_f, c_f, v_f = map(float, (o, h, l, c, v))
        except ValueError:
            nan_rows += 1
            continue
        rows += 1
        if first_ts is None:
            first_ts = ts
        last_ts = ts
        distinct_dates.add(date)
        if c_f <= 0 or o_f <= 0 or h_f <= 0 or l_f <= 0:
            zero_close += 1
        if v_f < 0:
            neg_vol += 1
        if not (l_f <= o_f <= h_f and l_f <= c_f <= h_f):
            ohlc_violations += 1
        if ts in seen_ts:
            dup_ts += 1
        else:
            seen_ts.add(ts)
        if ts_prev is not None and ts < ts_prev:
            non_monotonic += 1
        ts_prev = ts

print(f"header: {header}")
print(f"data rows: {rows}")
print(f"first ts: {first_ts}")
print(f"last ts:  {last_ts}")
print(f"distinct calendar days: {len(distinct_dates)}")
print(f"unparseable rows: {nan_rows}")
print(f"rows with price<=0: {zero_close}")
print(f"rows with vol<0: {neg_vol}")
print(f"OHLC violations (not L<=O,C<=H): {ohlc_violations}")
print(f"non-monotonic timestamps (this < previous): {non_monotonic}")
print(f"duplicate timestamps: {dup_ts}")
expected_minutes_full_coverage = int((last_ts - first_ts).total_seconds() / 60) + 1 if first_ts and last_ts else 0
print(f"calendar minute span: {expected_minutes_full_coverage}")
print(f"coverage ratio (rows / minutes spanned): {rows/expected_minutes_full_coverage:.4f}" if expected_minutes_full_coverage else "n/a")
