# Sprint 2 — Hotfix 3: диагностика chart data flow

**Дата:** 2026-05-17
**Метод:** статический анализ кода Astras (light-chart) ↔ bybit-adapter (history + BarsGetAndSubscribe). Браузерные DevTools не использовались (нет открытого сеанса) — выводы основаны на сопоставлении схем.

## TL;DR

**Найдена основная причина пустого chart:** несостыковка единиц `tf` между Astras и нашим adapter.

- **Astras `TimeframeValue` (frontend)** — `astras-bybit-ui/src/app/modules/light-chart/models/light-chart.models.ts`:
  ```ts
  M1 = '60'      // 1 минута = 60 СЕКУНД
  M5 = '300'     // 5 минут = 300 секунд
  M15 = '900'    // 15 минут = 900 секунд
  H = '3600'     // 1 час = 3600 секунд
  H4 = '14400'   // 4 часа = 14400 секунд
  Day = 'D' | W = 'W' | Month = 'M'
  ```
- **Adapter `TIMEFRAME_MAP` (`bybit-adapter/src/config/constants.ts`) ДО фикса:**
  ```ts
  '1': '1', '5': '5', '15': '15', '30': '30',
  '60': '60',     // ⬅️ читает как "60 МИНУТ" и отдаёт Bybit'у 1h kline
  '3600': '60',   // совпадение: '3600' маппится в '60' min ОК
  '240': '240', '14400': '240',
  D: 'D', '86400': 'D', W: 'W', M: 'M',
  ```

Когда пользователь выбирает в light-chart **1m**, Astras шлёт `tf: '60'`. Adapter читает это как "60 минут" и запрашивает Bybit kline interval `60` = **1 час**. Результат: вместо минутного графика приходят часовые свечи, что для свежего окна выглядит как почти пустой chart.

Когда пользователь выбирает **5m** (`tf: '300'`) или **15m** (`tf: '900'`), `TIMEFRAME_MAP['300']` и `TIMEFRAME_MAP['900']` дают `undefined`, fallback берёт `'300'`/`'900'` дословно. Bybit V5 API такие interval'ы отклоняет → `getKline` ошибка → `chart.history = []` → визуально пусто.

## Подтверждающие данные из кода

### 1. Astras light-chart datafeed подписка

`astras-bybit-ui/src/app/modules/light-chart/services/light-chart-datafeed.ts:73-81`:
```ts
const request: BarsRequest = {
  opcode: 'BarsGetAndSubscribe',
  code: this.instrumentKey.symbol,
  exchange: this.instrumentKey.exchange,
  instrumentGroup: this.instrumentKey.instrumentGroup,
  format: 'simple',
  tf: timeFrame,  // ⬅️ TimeframeValue (например '60' для 1m)
  from: this.lastHistoryPoint ?? this.getDefaultLastHistoryPoint(timeFrame)
};
```

И history запрос (`light-chart-datafeed.ts:38-46`):
```ts
this.historyService.getHistory({
  symbol: this.instrumentKey.symbol,
  exchange: this.instrumentKey.exchange,
  from: periodParams.from,
  to: periodParams.to,
  tf: this.timeFrame,  // тот же formate
  countBack: this.historyPointsCountBack
});
```

### 2. Default available timeframes для light-chart widget

`astras-bybit-ui/src/app/modules/light-chart/widgets/light-chart-widget/light-chart-widget.component.ts:68`:
```ts
availableTimeFrames: [TimeframeValue.M1, TimeframeValue.M15, TimeframeValue.H, TimeframeValue.Day],
```

То есть из коробки пользователю предлагается переключаться между `'60'`, `'900'`, `'3600'`, `'D'`. Из этих четырёх в нашем старом TIMEFRAME_MAP только `'3600'` и `'D'` маппились в правильный Bybit interval (`'60'` и `'D'`). `'60'` маппился неправильно (на `'60'` min вместо `'1'` min), а `'900'` вообще отсутствовал.

### 3. Adapter handlers

**REST history** (`bybit-adapter/src/routes/history.ts:26`):
```ts
const interval = TIMEFRAME_MAP[String(tf)] ?? String(tf);
```

**WS BarsGetAndSubscribe** (`bybit-adapter/src/ws/data-handler.ts:186-187`):
```ts
const tf = String(msg.tf ?? '1');
const interval = TIMEFRAME_MAP[tf] ?? tf;
const topic = `kline.${interval}.${symbol}`;
```

Оба места используют тот же `TIMEFRAME_MAP`, и оба ломаются на TF в секундах.

## Решение

Расширить `TIMEFRAME_MAP` чтобы он переваривал **обе** конвенции: ALOR-секундную (которая по факту используется во frontend) и TradingView-минутную (которая указана в комментарии к константе, но не используется light-chart-датафидом). Корректная таблица:

| Astras `tf` | Смысл       | Bybit V5 kline interval |
|-------------|-------------|-------------------------|
| `'1'`       | 1 сек       | `'1'` (1 мин — fallback, Bybit не имеет секундных свечей) |
| `'5'`       | 5 сек       | `'1'` |
| `'10'`      | 10 сек      | `'1'` |
| `'60'`      | **1 мин**   | `'1'` |
| `'300'`     | 5 мин       | `'5'` |
| `'900'`     | 15 мин      | `'15'` |
| `'1800'`    | 30 мин      | `'30'` |
| `'3600'`    | 1 ч         | `'60'` |
| `'14400'`   | 4 ч         | `'240'` |
| `'86400'`   | 1 д         | `'D'` |
| `'D'`       | дневной     | `'D'` |
| `'W'`       | недельный   | `'W'` |
| `'M'`       | месячный    | `'M'` |

Bybit V5 не поддерживает sub-minute kline для `linear`/`spot`, поэтому S1/S5/S10 мапятся на `'1'` (минуту) — light-chart всё равно покажет данные, просто более грубые. Если на стороне Astras пользователь явно требует sub-minute (для market making это редко нужно), это будет видно в логах adapter как запрос секундного TF — отдельный эпик, не блокер.

## Что НЕ является причиной пустоты chart

Чтобы Opus не тратил время на эти ветки:

1. **WS pong timeout (Epic 0)** — _может_ вызывать дропы live-баров, но history fetch (REST) от него не зависит. История пустая → бара пустые → chart пустой даже без WS issue.
2. **Auth** — light-chart на скриншоте видит instrument selector, портфель выбран; auth работает.
3. **CORS / network** — adapter на `localhost:3000`, Astras на `localhost:4200`, CORS уже настроен (ALOR endpoints типа `/md/v2/Securities` работают, что видно по тому что ticker показывает Ask).
4. **light-chart wrapper (Lightweight Charts)** — `lightweight-charts` (Apache-2.0) уже в deps; chart рисует пустой grid, значит библиотека загружена корректно. Проблема только в данных.
5. **Symbol routing** — после Hotfix 2 default `BTCUSDT`/`BYBIT`/`linear` — это валидный символ, `bybit.getKline({category: 'linear', symbol: 'BTCUSDT', ...})` возвращает данные при правильном interval.

## Подтверждение фикса (как проверить вручную)

После применения нового TIMEFRAME_MAP:

```bash
# REST history для 1m BTCUSDT
curl 'http://localhost:3000/md/v2/history?symbol=BTCUSDT&exchange=BYBIT&instrumentGroup=linear&tf=60&from=1715900000&to=1715920000&countBack=300'
# Должен вернуть {history: [...300 элементов с шагом 60s между ними...], prev, next}

# WS BarsGetAndSubscribe для 15m
# (через wscat или DevTools на astras frontend)
# Запрос: {"opcode":"BarsGetAndSubscribe","guid":"test","token":"...","code":"BTCUSDT","exchange":"BYBIT","instrumentGroup":"linear","tf":"900","from":1715900000,"format":"simple"}
# В adapter логах: topic = "kline.15.BTCUSDT" (а не "kline.900.BTCUSDT")
```

## Также записано в эпиках Sprint 2

- **Epic B (Chart + indicators)** — берёт за основу зафикшенный datafeed; индикаторы добавляются поверх через `technicalindicators` (MIT)
- **Epic A (Crypto layout)** — добавит light-chart на видное место crypto-friendly дашборда
- **Tech-chart как proprietary widget — disabled.** В Astras есть второй chart widget (`tech-chart`) поверх **TradingView Charting Library**, бандлы которой лежат в `astras-bybit-ui/src/assets/charting_library/` и `assets/lib/charting_library/`. По правилу проекта (100% OSS) этот widget использоваться не будет. Удаление бандлов и `tech-chart` модуля — отдельная задача в Epic B (OSS audit pass).
