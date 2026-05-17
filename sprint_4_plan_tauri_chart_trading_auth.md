# Sprint 4 Plan: Tauri Desktop Wrap + Chart Trading Phase 1 + Production Auth

## Контекст

Этот документ — **plan, не промпт для исполнения**. Он описывает scope Sprint 4 для архитектурного planning. Конкретный промпт для Claude Code будет создан после закрытия Sprint 3.

После Sprint 3 web версия Astras-bybit-ui будет functionally complete: рабочий Order Book без мерцания, Equity Curve, Blotter с live данными, WS stability проверена. Это работающий manual trading terminal в Chrome.

Sprint 4 превращает web версию в native desktop приложение и добавляет chart trading interactions, которые приближают UX к коммерческим решениям типа Bybit web UI.

## Обоснование Chart Trading в Sprint 4

Пользователь увидел на Bybit web UI:
- Кнопка [+] на оси цены для добавления ордера на конкретной цене кликом
- Active orders отображаются на chart как horizontal lines с label и кнопкой отмены
- Drag-to-move orders прямо на графике
- Right-click context menu для modify/cancel

Это standard chart trading UX. В оригинальном Bybit реализовано через **TradingView Advanced Charts** (proprietary), которая имеет нативные API:
- `createOrderLine()` — draggable horizontal line для ордера
- `createPositionLine()` — line для позиции с PnL display
- `createExecutionShape()` — маркеры исполнений
- Mouse event subscriptions с координатами

**Мы используем Lightweight Charts (Apache-2.0)**, которая намеренно не имеет этих interactive APIs — она spec'ована как pure visualization layer без trading UX слоя.

Решение: **custom interactive overlay на Angular** поверх Lightweight Charts. Это additive — не меняем chart engine, добавляем UX layer как separate component.

## Эпики Sprint 4

### Epic A: Tauri 2.0 desktop wrap

Превращение web SPA в native desktop приложение через Tauri 2.0 (MIT/Apache-2.0). Установщик `.msi` для Windows, `.dmg` для macOS (optional), `.AppImage` для Linux (optional).

**Архитектура:**
```
┌─────────────────────────────────────┐
│  Tauri shell (Rust, ~50 строк)      │
│  - Spawn Node.js sidecar (adapter)  │
│  - System tray + notifications      │
│  - Auto-update check                 │
│  - WebView rendering Angular SPA    │
└────────────────┬────────────────────┘
                 │ localhost:3000
                 ▼
┌─────────────────────────────────────┐
│  bybit-adapter (Node.js sidecar)    │
│  - Bundled с приложением            │
│  - Auto-start, auto-stop с Tauri    │
└─────────────────────────────────────┘
```

**Конкретные задачи:**
- Tauri init в `astras-bybit-ui` (новая папка `src-tauri/`)
- Bundle Node.js sidecar (есть Tauri plugin `tauri-plugin-shell`)
- System tray с иконкой, меню (Show/Hide, Quit)
- OS notifications на fill events (через `tauri-plugin-notification`)
- Hot reload в dev mode для итеративной разработки
- Production build с минимизацией bundle size
- Code signing — отложить (требует Apple Developer ID / Authenticode certificate, $99-200/год — не OSS-блокировка, но cost)

### Epic B: Chart Trading Phase 1 — click-to-place

**Реализация click-to-place ордеров прямо на графике.**

Frontend: новый компонент `chart-trading-overlay` в `astras-bybit-ui/src/app/features/chart-trading/`.

**Архитектура overlay:**
```
┌─────────────────────────────────────────────────┐
│  <div class="chart-container">                  │
│    <lightweight-chart></lightweight-chart>      │ <- Chart engine (Sprint 2)
│    <div class="chart-trading-overlay">          │ <- Наш кастомный layer
│      <button class="add-order-btn" />            │
│      <div class="order-line" *ngFor="..." />     │
│    </div>                                        │
│  </div>                                          │
└─────────────────────────────────────────────────┘
```

**Конкретные взаимодействия:**

1. **Add order button на оси цены:**
   - При hover на правую часть chart → показывается полупрозрачная кнопка [+] с текущей ценой курсора
   - Click → открыть quick order popup
   - Координата → цена через `priceScale().coordinateToPrice(y)`

2. **Quick order popup:**
   - Компактный modal (как Image 3 Bybit screenshot Сергея)
   - Pre-filled price из click coordinate
   - Quantity field (default = текущее значение из main Order Form, или 0.001 BTC)
   - Кнопки Buy / Sell (определяют side ордера)
   - Submit → POST limit order через adapter REST
   - Esc / Cancel → закрыть без действия

3. **Existing orders rendered as horizontal lines:**
   - Subscribe на active orders feed (Sprint 3 Blotter Epic делает это)
   - Каждый active order → render как absolute-positioned div через `priceScale().priceToCoordinate(price)`
   - Цвет: зелёный (buy) / красный (sell)
   - Label: "Лимитный {price} | {qty}" (как Image 2 Bybit screenshot)
   - На правом конце линии — X кнопка для cancel
   - При hover → highlight + show details tooltip

4. **Click on X → cancel:**
   - Confirm dialog (опционально)
   - DELETE order через adapter REST
   - Линия исчезает (WS update on order list)

5. **Re-render coordination:**
   - Chart pan/zoom → пересчитать y-coordinates для всех order lines
   - WS update active orders → update lines array reactively
   - Использовать Angular OnPush + trackBy for line components (urok из Sprint 3)

**Bybit V5 API constraints:**
- Spot vs Futures: для perpetual нужен `category=linear`
- Tick size: округление к `instruments-info.priceFilter.tickSize` (уже handled в adapter)
- Min order: проверять `instruments-info.lotSizeFilter.minOrderQty`

### Epic C: Production-ready authentication

Sprint 2 имеет mock JWT auth для local dev. Sprint 4 заменяет на production-grade:

**Архитектура:**
- При первом запуске app → onboarding screen
- Пользователь вводит Bybit API key + secret
- Adapter validates через `GET /v5/account/info`
- Если valid → encrypt и сохранить в OS-native credentials store:
  - Windows: Windows Credential Manager (`@napi-rs/keyring` или Tauri plugin)
  - macOS: Keychain
  - Linux: libsecret / Secret Service
- Adapter использует key для всех Bybit requests
- При запуске app → читает creds из store, validates connection

**OSS auth library:**
- `keyring` Rust crate (MIT/Apache-2.0) — Tauri side
- Или Node.js `keytar` (MIT) — adapter side, но deprecated по официальной рекомендации
- Лучше: Tauri plugin `tauri-plugin-stronghold` (Apache-2.0) — official secure storage solution

**UI/UX:**
- Onboarding wizard в Angular: welcome screen → API keys input → validation → success
- Settings page для смены keys позже
- Никаких keys в plain text файлах / localStorage / env files в production

### Epic D: Cleanup mock JWT auth (Sprint 2 legacy)

Из Sprint 2 остался hack:
```typescript
// В astras-bybit-ui auth bypass
if (!localStorage.getItem('jwt_token')) {
  // auto-fetch mock token from adapter
}
```

В Sprint 4 это убирается полностью — adapter использует encrypted Bybit creds напрямую, JWT нужен только для frontend ↔ adapter authentication (session-based, не Bybit-related).

### Epic E: App distribution preparation

- `.msi` installer для Windows через Tauri bundler
- `latest.json` release manifest для auto-update
- Self-hosted update server на GitHub Releases (Tauri поддерживает GitHub Releases как update channel)
- README в `astras-bybit-ui` с install instructions для конечных пользователей (не для разработчиков)

Это подготовка к **Sprint 6+** где (если стратегия валидируется) terminal становится distributable продуктом.

## Что НЕ делаем в Sprint 4

- Chart Trading Phase 2 (drag-to-move) — Sprint 5
- Chart Trading Phase 3 (context menus, position lines) — Sprint 5
- Hummingbot integration — Sprint 5
- Backtest — Sprint 6
- Multi-account — Sprint 6+
- Mobile / responsive — позже

## Расчётный timeline

15-20 рабочих дней full-time для Sprint 4. Возможные тормоза:
- Tauri sidecar для Node.js может иметь quirks (packaging, paths)
- Chart Trading overlay требует careful coordinate math (chart pan/zoom)
- Encrypted credentials storage cross-platform — testing на Windows должно быть достаточно

## Зависимости и риски

**OSS constraint:**
- Tauri 2.0 — MIT/Apache-2.0 ✅
- tauri-plugin-stronghold — Apache-2.0 ✅
- Все Angular libraries для overlay — внутри Astras ecosystem

**Технические риски:**
- Lightweight Charts coordinate API стабилен (no breaking changes ожидаются)
- Tauri sidecar packaging Node.js — тестировано community, но nuances on Windows
- Bybit API rate limits — если chart trading triggerит много order updates, нужно client-side throttling

## После Sprint 4

После Sprint 4 у нас:
- Native desktop приложение для Windows (с инсталлером)
- Click-to-place ордера прямо с графика
- Active orders отображаются как horizontal lines на chart
- Secure encrypted credentials
- App can be distributed (даже если пока без code signing)

Это позволяет:
1. **Использовать самим в Mainnet** (после Sprint 5 Hummingbot integration)
2. **Раздавать другим тестерам** (open source — любой может склонить и собрать)
3. **Готовиться к monetization** — Premium tier features в Sprint 6+ (мониторинг сторонних accounts, alerts, advanced layouts)

## Sprint 5 preview (для контекста)

**Эпики Sprint 5:**
- Hummingbot integration: запуск PMM Dynamic стратегии на BTCUSDT testnet
- Chart Trading Phase 2: drag-to-move existing orders
- Chart Trading Phase 3: right-click context menus, position lines с PnL
- Strategy parameters UI: GUI для редактирования YAML конфигов Hummingbot
- Bot status panel: live monitoring запущенных Hummingbot instances из Astras

Это финальная фаза перед mainnet trading. После Sprint 5 — Sprint 6 backtest, Sprint 7+ mainnet и monetization.
