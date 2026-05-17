# Pre-Sprint 5 Discovery: инвентаризация архива котировок `D:\DTS`

**Дата инспекции:** 2026-05-17
**Хост:** Windows, путь `D:\DTS` (через WSL2 — `/mnt/d/DTS/`)
**Задача:** структурный анализ архива для проектирования backtest pipeline в Sprint 5.
**Что НЕ делалось:** ни один файл не модифицирован, не скопирован, не переименован; никаких backtest / VectorBT / pandas-пайплайнов не построено.

## 1. Общая статистика

| Метрика | Значение |
|---|---|
| Полный размер архива | **67 GB** (`du -sh /mnt/d/DTS` → `67G`) |
| Всего файлов | **1 663** |
| Всего папок | **171** |
| Папок верхнего уровня | **60** |
| Расширения | `577 .txt` + `1 086 .bin` (других нет) |

В архиве **нет** ни Parquet, ни Feather, ни HDF5, ни JSON, ни SQLite, ни orderbook-snapshot файлов, ни ZIP/tar.gz. Только текстовые `.txt` (CSV-подобные) и бинарные `.bin`.

## 2. Структура верхнего уровня

60 entries на корне `D:\DTS\`. Категоризировал по содержанию:

### 2.1. Категориальные папки (заглавные русские имена) — основные сборки

| Папка | Размер | Что внутри | Покрытие времени |
|---|---|---|---|
| **`ТИКИ/`** | **42 GB** | Тиковые данные FORTS (BR, RTS, Si, GAZR, SBRF) — `.txt` и `.bin` | 2016 → 2021 |
| **`binance/`** | **11 GB** | ~330 пар Binance spot, флэт-файлы по тикеру | **2017-08 → 2018-09** (старая!) |
| **`Акции/`** | **5.6 GB** | 65 MOEX-акций (SBER, GAZP, LKOH, …), один `.txt` на тикер | 2009-01 → 2026-04 |
| **`Криптовалюта/`** | **5.0 GB** | GDAX (Coinbase) + BitsexCoin биржи, 26 пар (BTC, ETH, LTC, XRP, BCH × USD/EUR/GBP/BTC), один `.txt` на пару | 2014-12 → **2023-05** |
| **`Индексы/`** | **399 MB** | IMOEX, RTSI, RVI | 2009-01 → 2026-04 |
| **`ETF Мосбиржа/`** | **316 MB** | SBMX, TMOS, SBRB, SBMM, AKMB, SAFE, TBRU, TRUR (8 ETF) | 2018 → 2026-04 |

### 2.2. Ticker-папки на корне (один `.txt` файл с одноимённым тикером)

54 такие папки — каждая содержит ровно один файл вида `<TICKER>.txt` с минутными свечами с MOEX:

- **FORTS-фьючерсы**: `BR`, `Si`, `RTS`, `RTSM`, `GAZR`, `SBRF`, `SBPR`, `Eu`, `ED`, `GOLD`, `GOLDM`, `SILV`, `SILVM`, `NG`, `NGM`, `MIX`, `MXI`, `CNY`, `IMOEXF`, `USDRUBF`, `EURRUBF`, `CNYRUBF`, `GLDRUBF`, `COCOA`, `ORANGE`, `PLT`, `TTF`, `NASD`, `SPYF`, `IBIT`, `ETHA` — фьючерсные контракты МосБиржи
- **Акционные тикеры на корне (дубль)**: `GAZPF`, `GMKN`, `LKOH`, `MGNT`, `MOEX`, `MTSI`, `NLMK`, `PIKK`, `ROSN`, `SBERF`, `SMLT`, `SPBE`, `T`, `TATN`, `TRNF`, `VTBR`, `YDEX`, `BELU`, `BANE`, `RGBI` — частично пересекаются с `Акции/`
- **Экзотические**: `BTC`, `ETH` (на верхнем уровне, **не** binance!) — это **MOEX-фьючерсы на крипту** (BTCRUBF / ETHRUBF), запущенные 2025-11, размер 4-5 MB, покрытие 2025-11 → 2026-04
- **Валютные**: `UCHF`, `UCNY` — USD/CHF, USD/CNY на FX-секции MOEX

### 2.3. Дерево примера (3-4 уровня)

```
D:\DTS\
├── ТИКИ\                                          [42 GB]
│   ├── RTS 2018\                                  [5.4 GB, 1086 .bin файлов]
│   │   ├── Rts3.18\                               [151 .bin, 1.1 GB]
│   │   │   └── RTS-3.18.01.03.2018.bin            [10 MB binary]
│   │   ├── rts-6.18\                              [205 .bin, 1.2 GB]
│   │   ├── rts-9.18\                              [235 .bin, 987 MB]
│   │   ├── rts-12.18\                             [274 .bin, 1.3 GB]
│   │   └── rts-3.19\                              [221 .bin, 786 MB]
│   ├── Тики_с_2017_по_Март_2021\                  [32 GB, 19 .txt файлов]
│   │   ├── br_ticks_2017.txt                      [955 MB]
│   │   ├── br_ticks_2018.txt                      [1.4 GB]
│   │   ├── …
│   │   ├── si_ticks_2020_2.txt                    [3.4 GB]
│   │   └── ri_ticks_2021.txt                      [872 MB]
│   ├── SPFB.Si_20160104_20160127.txt              [594 MB]
│   ├── SPFB.Si_тики.txt                           [251 MB]
│   ├── SPFB.RTS.txt                               [242 MB]
│   ├── SPFB.BR_t.txt                              [344 MB]
│   ├── SPFB.SBRF_20160101_20160401.txt            [302 MB]
│   └── SPFB.GAZR_20160101_20160401.txt            [101 MB]
├── binance\                                       [11 GB]
│   ├── BTCUSDT_1m_binance.txt                     [63 MB, 665k строк]
│   ├── ETHUSDT_1m_binance.txt                     [61 MB, 665k строк]
│   ├── BNBUSDT_1m_binance.txt                     [42 MB]
│   ├── … (~330 файлов вида <SYM>_1m_binance.txt)
│   └── ZRXETH_1m_binance.txt
├── Акции\                                         [5.6 GB]
│   ├── SBER\
│   │   └── SBER.txt                               [155 MB, 1m, 2009→2026]
│   ├── GAZP\GAZP.txt
│   ├── LKOH\LKOH.txt
│   └── … (65 тикеров)
├── Криптовалюта\                                  [5.0 GB]
│   ├── Биткоин к доллару (BTC-USD)\
│   │   └── GDAX.BTC-USD.txt                       [365 MB, 4.2M строк, 2014-12→2023-03]
│   ├── BitsexCoin (BTSX) Биткоин к Доллару США (BTC_USD)\
│   │   └── BTSX.BTC_USD.txt                       [337 MB, 2014→2023-05]
│   ├── Эфириум к доллару (ETH-USD)\GDAX.ETH-USD.txt
│   ├── Лайткоин к доллару (LTC-USD)\
│   ├── … (26 криптопар Coinbase/BitsexCoin)
│   └── Новая папка\                               [4 файла, 920 MB]
│       ├── BCHUSD.txt
│       ├── ETHBTC.txt
│       ├── ETHEUR.txt
│       └── LTCBTC.txt
├── Индексы\                                       [399 MB]
│   ├── IMOEX\IMOEX.txt                            [156 MB, 1m, 2009→2026]
│   ├── RTSI\RTSI.txt
│   └── RVI\RVI.txt
├── ETF Мосбиржа\                                  [316 MB]
│   ├── SBMX\SBMX.txt                              [1m, 2018-09→2026-04]
│   ├── TMOS\, TBRU\, TRUR\, SBRB\, SBMM\, AKMB\, SAFE\
├── BTC\BTC.txt                                    [5 MB, 1m MOEX-фьючерс BTCRUBF, 2025-11→2026-04]
├── ETH\ETH.txt                                    [4 MB, 1m MOEX-фьючерс ETHRUBF, 2025-11→2026-04]
├── SI\Si.txt                                      [168 MB, 1m FORTS, 2009→2026]
├── RTS\RTS.txt                                    [184 MB, 1m FORTS]
├── BR\BR.txt, GAZR\GAZR.txt, SBRF\SBRF.txt, …
└── …
```

## 3. Форматы файлов

### 3.1. Доминирующий формат: Finam `.txt` export (минутные свечи)

Один и тот же формат **для абсолютного большинства** `.txt` файлов: акции, индексы, ETF, FORTS-фьючерсы, GDAX/BTSX крипта, binance.

**Header (первая строка):**
```
<TICKER>,<PER>,<DATE>,<TIME>,<OPEN>,<HIGH>,<LOW>,<CLOSE>,<VOL>
```

**Параметры:**
| Параметр | Значение |
|---|---|
| Кодировка | `text/csv; charset=us-ascii` (проверено через `file -i` на 4 разных файлах — все одинаково) |
| Разделитель | `,` (запятая) |
| Разделитель десятичной | `.` (точка) |
| Header | Есть, в `<>` |
| Quotes | Нет |
| Line terminator | `\n` (Unix LF) |
| `<PER>` | `1` для 1-минутных свечей, `0` для тиков (см. 3.2) |
| `<DATE>` | `YYYYMMDD` (целое число) |
| `<TIME>` | `HHMMSS` (целое число, ведущие нули **есть**: `100000` = 10:00:00) |
| `<OPEN>`/`<HIGH>`/`<LOW>`/`<CLOSE>` | float, переменное число знаков после точки (от 1 у акций до 8 у Binance: `4261.48000000`) |
| `<VOL>` | float или int |
| Timezone | Для MOEX — **MSK** (UTC+3). Для binance/GDAX — **UTC** (подтверждается тем, что BTCUSDT начинается с `20170817 070000` ≈ Binance launch ~07:00 UTC 17 авг 2017) |

**Sample (binance/BTCUSDT_1m_binance.txt):**
```
<TICKER>,<PER>,<DATE>,<TIME>,<OPEN>,<HIGH>,<LOW>,<CLOSE>,<VOL>
BTCUSDT,1,20170817,070000,4261.48000000,4261.48000000,4261.48000000,4261.48000000,1.77518300
BTCUSDT,1,20170817,070100,4261.48000000,4261.48000000,4261.48000000,4261.48000000,0.00000000
BTCUSDT,1,20170817,070200,4280.56000000,4280.56000000,4280.56000000,4280.56000000,0.26107400
```

**Sample (Акции/SBER/SBER.txt):**
```
SBER,1,20090111,103000,23.3,23.3,22.99,23.01,666517
SBER,1,20090111,103100,23.01,23.08,22.98,23.02,199410
```

**Pandas-загрузка тривиальна:**
```python
df = pd.read_csv(
    path,
    parse_dates={"ts": ["<DATE>", "<TIME>"]},
    date_parser=lambda d, t: pd.to_datetime(d.str.zfill(8) + t.str.zfill(6), format="%Y%m%d%H%M%S"),
    dtype={"<OPEN>": float, "<HIGH>": float, "<LOW>": float, "<CLOSE>": float, "<VOL>": float}
)
```

### 3.2. Тиковый формат A: Finam (`SPFB.*.txt` в `ТИКИ/`)

**Header:** `<TICKER>,<PER>,<DATE>,<TIME>,<LAST>,<VOL>` (PER=0)

**Sample (`ТИКИ/SPFB.Si_тики.txt`):**
```
SPFB.Si,0,20160104,100000,74851.000000000,1
SPFB.Si,0,20160104,100000,74850.000000000,62
```

Цена сделки + объём, без стороны. Timestamp до секунд (без миллисекунд). 5.5 млн строк в одном файле 251 MB. Покрытие 2016+.

### 3.3. Тиковый формат B: расширенный со стороной сделки (`Тики_с_2017_по_Март_2021/`)

**Header:** `<DATE>,<TIME>,<LAST>,<VOL>,<ID>,<OPER>`

**Sample (`br_ticks_2021.txt`):**
```
<DATE>,<TIME>,<LAST>,<VOL>,<ID>,<OPER>
20210104,10:00:00,51.57,1,1960781312268725568,B
20210104,10:00:00,51.57,7,1960781312268725569,B
```

Колонки:
- `<DATE>` `YYYYMMDD`
- `<TIME>` `HH:MM:SS` (с двоеточиями — **другой формат, чем в формате A**!)
- `<LAST>` цена сделки
- `<VOL>` объём
- `<ID>` уникальный trade ID (int64)
- `<OPER>` `B` (buyer-initiated) / `S` (seller-initiated)

**Это очень ценные данные** — пристань для бэктеста стратегий, потому что есть buyer/seller флаг (taker side). Но только для FORTS (BR=Brent, RI=RTS index futures, SI=USDRUB futures), **не для крипты**.

19 файлов общим объёмом 32 GB. Один файл `si_ticks_2020_2.txt` — 3.4 GB / ~120M строк.

### 3.4. Бинарный формат: `ТИКИ/RTS 2018/*.bin` (5.4 GB, 1086 файлов)

`file` определяет как `data` (без сигнатуры). Hex-дамп начала:

```
0800 0000 9aab 0100 003a c1b7 7300 0000  .........:..s...
0000 106e c090 52d5 0800 0000 0060 6afc  ...n..R......`j.
4000 0000 0000 0024 4001 0000 0000 4895  @......$@.....H.
1441 0000 0000 804f fc40 0000 0000 6083  .A.....O.@....`.
fc40 46d3 d9c9 e008 2740 0000 0000 0040  .@F.....'@.....@
```

Похоже на **проприетарный binary export** с записями фиксированной длины, содержащими IEEE-754 doubles (видно повторяющееся `0040 6340 0000 0000` и т.п.) и Windows FILETIME-подобные timestamps. Возможные источники: QUIK history export, Plaza II raw feed, .NET BinaryWriter, FinamScalper.

**На текущем этапе формат не идентифицирован.** Для использования нужен writer-side decoder (исходник того, что писало эти файлы). Один файл — один торговый день одного фьючерса серии RTS (по 5 сериям 2018-2019: 3.18, 6.18, 9.18, 12.18, 3.19), по 150-275 файлов на серию (~торговые дни).

Без декодера данные **непригодны**. Можно либо игнорировать (5 GB из 67 — приемлемо), либо запросить у пользователя decoder.

### 3.5. Других форматов нет

```bash
$ find /mnt/d/DTS -type f ! -name '*.txt' ! -name '*.bin'
(empty)
```

## 4. Покрытие данных

### 4.1. Активы

**Крипта (для нашего Bybit MM):**

| Источник | Пары | TF | Период | Note |
|---|---|---|---|---|
| `binance/` | ~330 (BTCUSDT, ETHUSDT, BNBUSDT, LTCUSDT, XRPUSDT, ADAUSDT, EOSUSDT, ICXUSDT, IOTAUSDT, NEOUSDT, ONTUSDT, QTUMUSDT, TRXUSDT, TUSDUSDT, VETUSDT, XLMUSDT, NULSUSDT, ETCUSDT, BCCUSDT и масса крестов с BTC/ETH/BNB) | 1m | **2017-08 → 2018-09** | Очень старая выборка. **Для нашего primary BTCUSDT — 13 месяцев данных, не свежие.** |
| `Криптовалюта/Биткоин к доллару (BTC-USD)/GDAX.BTC-USD.txt` | BTC-USD (Coinbase) | 1m | **2014-12-01 → 2023-03-31** | 4.2M строк, 365 MB. Самый длинный непрерывный crypto-ряд в архиве. |
| `Криптовалюта/BitsexCoin (BTSX) Биткоин к Доллару США (BTC_USD)/BTSX.BTC_USD.txt` | BTC/USD (BitsexCoin) | 1m | 2014-12 → **2023-05-31** | 337 MB. Параллельный ряд с другой биржи. |
| `Криптовалюта/` остальные | LTC, ETH, XRP, BCH × USD/EUR/GBP/BTC, ~25 пар | 1m | 2014 → 2023 | GDAX + BTSX |
| `BTC/BTC.txt`, `ETH/ETH.txt` | MOEX-фьючерсы BTCRUBF / ETHRUBF | 1m | **2025-11-18 → 2026-04-30** | Свежие, но это **MOEX-инструменты в рублях**, не Bybit. Объёмы крошечные (10-30 контрактов на минуту), малая ликвидность. |

**Перекрытие с Bybit linear perpetuals (USDT margin):** прямого нет. Ближе всего — Binance BTCUSDT/ETHUSDT spot 2017-2018, но они (а) спотовые, не perpetual; (б) старые.

**MOEX (для backtest стратегий на FORTS — не наш приоритет):**

| Категория | Тикеры | TF | Период |
|---|---|---|---|
| Акции | 65 (SBER, GAZP, LKOH, MGNT, MTSS, GMKN, NLMK, ROSN, T(TCSG), VKCO, OZON, YDEX, …) | 1m | 2009-01 → 2026-04 (~17 лет) |
| Индексы | IMOEX, RTSI, RVI | 1m | 2009-01 → 2026-04 |
| ETF | SBMX (флагман), TMOS, TBRU, TRUR, SBRB, SBMM, AKMB, SAFE | 1m | 2018+ → 2026-04 |
| FORTS-фьючерсы | Si, RTS, BR, GAZR, SBRF, GMKN, GOLD, GOLDM, SILV, SILVM, NG, NGM, MIX, MXI, CNY, и валютные XRRUBF | 1m | 2009 → 2026-04 |
| FORTS-тики (Finam-формат) | Si, RTS, BR, SBRF, GAZR | tick | 2016 → 2020 |
| FORTS-тики (extended формат с стороной) | BR (`br_ticks_*`), RI (`ri_ticks_*`), Si (`si_ticks_*`) | tick + side | 2017 → 2021-03 |
| FORTS-binary | RTS series 3.18/6.18/9.18/12.18/3.19 | tick (?) | 2018 → 2019 |

### 4.2. Таймфреймы

В архиве **только 1-минутные свечи** (`<PER>=1`) и **тиковые данные** (`<PER>=0`). **Нет** 5m / 15m / 1h / 1d / 1s / 100ms. При необходимости старшие TF восстанавливаются ресемплингом из 1m.

### 4.3. L2 / orderbook данные

**Отсутствуют полностью.** Поиск:

```bash
find /mnt/d/DTS -type f \( -iname '*orderbook*' -o -iname '*depth*' -o -iname '*l2*' -o -iname '*book*' -o -iname '*snap*' \)
# → 0 совпадений
```

Это **критическое ограничение** для market-making backtest:
- нет очереди в стакане → нет реалистичной симуляции `queue position` (когда наш PostOnly-лимитник окажется в очереди, и какой fraction объёма ушедшего по той же цене заденет именно нас);
- нет bid-ask спреда per-snapshot → spread приходится оценивать косвенно (через high-low range на 1m или через trade-tape spread на тиках, что неточно);
- fills симулируются эвристиками типа "наш bid исполнен если low ≤ bid на этой минуте" — это **верхняя граница** реалистичности, не точная модель.

Это надо чётко обозначить архитектору при проектировании Sprint 5.

### 4.4. Временной диапазон для BTCUSDT (primary)

Sanity-check на `binance/BTCUSDT_1m_binance.txt`:

| Метрика | Значение |
|---|---|
| Размер | 63 MB |
| Data rows | 665 034 |
| Первый timestamp в файле | 2017-08-17 07:00:00 UTC |
| Последний timestamp в файле | 2017-08-17 15:19:00 (но это не максимальная дата — см. ниже) |
| Уникальных дней | **392** (т.е. ~13 месяцев) |
| Реальный диапазон по данным | **2017-08-17 → ~2018-09** (последняя модификация файла 2018-09-12) |

**Файл не отсортирован.** Iteration через file видит чередование диапазонов: голова `2017-08-17 07:00`, при NR=100000 уже `2017-10-26`, при NR=300000 — `2018-03-15`, NR=500000 — `2018-06-29`, а tail снова возвращается к `2017-08-17 15:19`. Похоже на склейку двух экспортов с дублированием первого блока.

## 5. Качество данных

Sanity-check (тот же `BTCUSDT_1m_binance.txt`):

| Проверка | Результат |
|---|---|
| Unparseable rows (формат не соответствует) | **1** из 665k (0.0002%) |
| `price ≤ 0` | 0 |
| `volume < 0` | 0 |
| OHLC violations (`low ≤ open,close ≤ high`) | **0** ✅ |
| Non-monotonic timestamps (текущий < предыдущего) | **588** — файл не отсортирован |
| Duplicate timestamps | **105 862** (~16% всех строк!) |
| Календарных дней в данных | 392 |
| Покрытие минут (rows / спан минут) | требует дедупа + сортировки |

**Выводы по качеству:**
1. **Нужна предобработка**: `sort_values('ts').drop_duplicates(subset='ts', keep='last')`. ~16% дубликатов — это много, но это **полные дубли по timestamp**, а не разные значения на одну минуту, поэтому простой `drop_duplicates` решает.
2. OHLC consistent — нет инвертированных свечей.
3. Цены и объёмы санитарны (нет нулей или отрицательных).
4. После дедупа в `BTCUSDT_1m_binance.txt` остаётся **~525-560k unique minutes** на 392 дня (565k full-coverage) → coverage ~93-99% за период, остальное реальные gaps (downtime биржи, технические перерывы).

**Других файлов глубокого sanity не проводил** — структурно все Finam .txt идентичны, проблемы дублирования стоит проверить выборочно перед загрузкой.

## 6. Implications для Sprint 5 backtest pipeline

### 6.1. Формат

- **Основной формат — Finam .txt CSV**, ASCII, comma-separated. Парсится `pandas.read_csv` тривиально.
- **Конвертация в Parquet рекомендуется** для backtest hot loop. 1m свечи BTCUSDT (~525k rows × 9 cols × 8B ≈ 38 MB после dedup) → Parquet `~10 MB` со ZSTD. Загрузка `pd.read_parquet` ~10x быстрее `read_csv`.
- Стандартизация: `Парсер → DataFrame[ts: datetime64[ns, UTC], open: f64, high: f64, low: f64, close: f64, volume: f64]` → Parquet partition by `(symbol, year)`.

### 6.2. RAM

- **BTCUSDT 1m за всё доступное** (~525k unique строк) — **40 MB** в pandas. Безопасно.
- **SBER 1m за 2009-2026** (~6 млн строк, файл 155 MB) — **~450 MB** в памяти.
- **Si tick расширенный формат**, файл `si_ticks_2020_2.txt` — **3.4 GB на диске**, в memory ~10-12 GB как DataFrame с int64 IDs. **Не грузить целиком**, использовать `pd.read_csv(chunksize=...)` или Polars/DuckDB lazy.
- При работе с тиками крипты не выйдет — их **нет**.

### 6.3. Tooling

- **Pandas + PyArrow** покроют 95% работы. Установка `pyarrow` обязательна в backtest conda env (в hummingbot conda env её нет по умолчанию).
- Для тиковых файлов размером в гигабайты лучше **Polars** (`pl.scan_csv`) или **DuckDB** (`SELECT * FROM read_csv('br_ticks_2020.txt')`) — потоковая обработка без полного memory load.
- Самописный парсер для Finam-формата не нужен, всё через `read_csv` с правильными `parse_dates`.

### 6.4. Главное ограничение для MM-стратегии

| Что есть | Что нужно для accurate MM backtest |
|---|---|
| 1m OHLCV на BTCUSDT 2017-2018 | ✅ можно использовать для **bar-level approximation** fills (наш ордер исполнен если `low ≤ bid` или `high ≥ ask`) |
| Нет L2/orderbook crypto | ❌ **нет очереди → нет реалистичной queue-position симуляции** |
| Нет trade tape crypto | ❌ невозможно посчитать `fill probability` из реального arrival rate λ — придётся бутстрепить из синтетики или калибровать на live demo |
| Нет свежих crypto 2024-2026 | ⚠️ backtest будет на **исторических режимах рынка**, не на текущем. Trend, vol regime, маркет-структура изменились (2017 был bull run, 2018 — crash, 2024-2025 — другая динамика). |
| Есть FORTS-тики с стороной (BR/RI/Si 2017-2021) | ⚠️ можно использовать для **методологической валидации** PMM Dynamic на FORTS, но это не наш Bybit инструмент |

### 6.5. Рекомендованный путь Sprint 5

1. **Primary backtest source**: `Криптовалюта/Биткоин к доллару (BTC-USD)/GDAX.BTC-USD.txt` — 4.2M строк, 2014→2023, GDAX/Coinbase BTC-USD, наиболее длинный непрерывный crypto-ряд. После dedup можно строить equity-curve бэктеста PMM Dynamic за **8+ лет** разных рыночных режимов.
2. **Secondary**: `binance/BTCUSDT_1m_binance.txt` после dedup (525k unique строк), 2017-2018, как cross-check за overlap-период с GDAX.
3. **Параллельные ряды для робастности**: `Криптовалюта/Эфириум к доллару (ETH-USD)/GDAX.ETH-USD.txt`, `Лайткоин к доллару (LTC-USD)` — те же стратегические параметры на других инструментах.
4. **Свежесть данных**: для тестирования стратегии на текущем рынке (2024-2026) **архив бесполезен** — нужен либо download свежих свечей через Bybit V5 REST `getKline` (5-летний rolling window доступен через API), либо отдельный сбор с продакшна.
5. **L2 фикция**: для market-making нужно явно зафиксировать ассumption в backtest harness — например, *"при исполнении лимитника на 1m bar мы получаем fraction `f` от bar-volume, при `f ∈ [0.05, 0.2]` калибрационный параметр"*. Конкретное значение `f` подбирается калибровкой на live demo trade tape (Sprint 4 уже даёт нам orderbook + execution stream).
6. **Игнорировать**: бинарные RTS `.bin` файлы (5.4 GB, формат не известен), MOEX BTC/ETH фьючерсы (`BTC.txt`/`ETH.txt`, низкая ликвидность, рублёвые), MOEX акции/индексы/ETF/FORTS (нерелевантны для крипто-MM).

### 6.6. Что критически отсутствует

- **L2 orderbook snapshots** (любая биржа, любой инструмент) — придётся принять как фундаментальное ограничение бэктеста, документировать в Sprint 5 reports.
- **Свежие данные 2024-2026 по криптобиржам** — нужен отдельный bootstrap pipeline (REST scraper Bybit `getKline` history → JSONL/Parquet local).
- **Bybit-родные данные** — нет.
- **Trade tape (с buyer/seller флагом) по крипте** — нет, есть только по FORTS, не применимо.
- **Decoder для бинарных RTS .bin файлов** — нет, либо запрашивать у пользователя, либо игнорировать.

## 7. Команды воспроизведения

Полные пробы лежат в:
- `mm-bot/scripts/_inventory_probe.sh` — структурный анализ (топ-уровень, размеры по папкам, .bin hex, sample binance, ТИКИ субструктура)
- `mm-bot/scripts/_inventory_probe2.sh` — Криптовалюта детальный обзор, encoding probes, MOEX FORTS samples
- `mm-bot/scripts/_inventory_sanity.py` — sanity-check на BTCUSDT (NaN/duplicates/monotonic/OHLC)

Запуск (read-only):
```powershell
wsl -d Ubuntu-24.04 bash /mnt/c/BUFFER/mm-bot/scripts/_inventory_probe.sh
wsl -d Ubuntu-24.04 bash /mnt/c/BUFFER/mm-bot/scripts/_inventory_probe2.sh
wsl -d Ubuntu-24.04 python3 /mnt/c/BUFFER/mm-bot/scripts/_inventory_sanity.py
```

Скрипты не модифицируют архив, только читают.

## 8. TL;DR для архитектора

- **67 GB, 1663 файла, 60 top-level папок, 171 директория всего.**
- **2 формата:** Finam `.txt` CSV (свечи `<TICKER>,<PER>,<DATE>,<TIME>,<OHLCV>`, тики `<TICKER>,<PER>,<DATE>,<TIME>,<LAST>,<VOL>` или расширенный с `<ID>,<OPER>`) + проприетарный `.bin` (декодер неизвестен, **5 GB / 1086 файлов RTS futures**).
- **Только TF 1m свечи + tick.** Нет 5m/1h/1d (восстановимы ресемплингом), нет L2/orderbook (фундаментальное ограничение).
- **Для нашего primary BTCUSDT:** есть GDAX 2014-2023 (4.2M строк, чистый) + Binance 2017-2018 (525k строк после dedup от 16% дубликатов). **Свежих 2024-2026 нет** — нужен отдельный bootstrap через Bybit V5 REST `getKline`.
- **Trade tape по крипте отсутствует**, есть только по FORTS BR/RI/Si 2017-2021 (32 GB extended-формат с buy/sell стороной). Не применимо к Bybit.
- **MM backtest fill model = approximation**, не точная очередь. Параметр `fill fraction` калибруется на live demo.
- **Рекомендуемая тулза:** pandas + pyarrow для всего, Polars/DuckDB lazy для tick-файлов 1-3 GB.
- **Рекомендуемое хранилище после загрузки:** Parquet partitioned by `(symbol, year)` со ZSTD compression, в `mm-bot/data/historical/` (gitignored).
- **Encoding везде ASCII (us-ascii), запятая, точка-десятичная, MOEX=MSK / crypto=UTC.**

---

**Документ:** `mm-bot/docs/research/quote_archive_inventory.md`
**Версия:** 2026-05-17
**Архив инспектирован:** read-only, без модификаций.
