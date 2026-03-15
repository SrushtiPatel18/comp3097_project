# SmartPocket

A personal finance tracker originally written as a native iOS app (SwiftUI + SwiftData). The original iOS source is preserved in the `SmartPocketIOS/` directory. A fully functional web version has been built using React + Vite in the `web/` directory.

## Project Structure

```
SmartPocketIOS/         Original iOS/Swift source code (SwiftUI + SwiftData)
  ├── Models.swift      Data models: SPTransaction, SPCategory, SPSettings
  ├── HomeView.swift    Budget dashboard
  ├── TransactionsListView.swift  Full transaction list with search/filter
  ├── ReportsView.swift Spending charts (pie chart + calendar view)
  ├── settingsView.swift Budget and category management
  └── Theme.swift       Design tokens (purple/blue palette, CAD currency)

web/                    React + Vite web app (browser-runnable version)
  ├── src/
  │   ├── App.jsx       Root with tab navigation
  │   ├── HomeView.jsx  Budget dashboard with recent transactions
  │   ├── TransactionsView.jsx  Full list with search, filter, CRUD
  │   ├── ReportsView.jsx  Pie chart (recharts) + calendar date picker
  │   ├── SettingsView.jsx  Budget edit, category CRUD, data reset
  │   ├── AddTransactionModal.jsx  Add/edit bottom sheet form
  │   ├── TransactionDetailModal.jsx  View/edit/delete detail sheet
  │   ├── store.js      localStorage-backed state management
  │   └── utils.js      CAD currency formatting, category icons, chart colors
  └── vite.config.js    Host 0.0.0.0, port 5000, allowedHosts: true
```

## Features

- Budget tracking with monthly progress bar (CAD)
- Add / edit / delete transactions (income & expenses)
- Category-based spending with pie chart
- Calendar view to browse transactions by date
- Full-text search and income/expense filtering
- Custom category management
- localStorage persistence

## Tech Stack

- **Web**: React 19, Vite 8, Recharts
- **iOS** (original): Swift 5.8, SwiftUI, SwiftData, Charts

## Running

The workflow `Start application` runs `cd web && npm run dev` on port 5000.

## Deployment

Configured as a static site. Build: `cd web && npm run build`. Public dir: `web/dist`.
