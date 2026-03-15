import { useState } from 'react';
import { useStore } from './store.js';
import HomeView from './HomeView.jsx';
import TransactionsView from './TransactionsView.jsx';
import ReportsView from './ReportsView.jsx';
import SettingsView from './SettingsView.jsx';
import './App.css';

function HomeIcon({ active }) {
  return (
    <svg viewBox="0 0 24 24" fill={active ? 'currentColor' : 'none'} stroke="currentColor" strokeWidth={2}>
      <path d="M3 9.5L12 3l9 6.5V20a1 1 0 01-1 1H4a1 1 0 01-1-1V9.5z" />
      <path d="M9 21V12h6v9" />
    </svg>
  );
}

function ListIcon({ active }) {
  return (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2}>
      <line x1="8" y1="6" x2="21" y2="6" />
      <line x1="8" y1="12" x2="21" y2="12" />
      <line x1="8" y1="18" x2="21" y2="18" />
      <circle cx="3" cy="6" r={active ? 1.5 : 1} fill="currentColor" />
      <circle cx="3" cy="12" r={active ? 1.5 : 1} fill="currentColor" />
      <circle cx="3" cy="18" r={active ? 1.5 : 1} fill="currentColor" />
    </svg>
  );
}

function ChartIcon({ active }) {
  return (
    <svg viewBox="0 0 24 24" fill={active ? 'currentColor' : 'none'} stroke="currentColor" strokeWidth={2}>
      <path d="M21.21 15.89A10 10 0 1 1 8 2.83" />
      <path d="M22 12A10 10 0 0 0 12 2v10z" />
    </svg>
  );
}

function GearIcon({ active }) {
  return (
    <svg viewBox="0 0 24 24" fill={active ? 'currentColor' : 'none'} stroke="currentColor" strokeWidth={1.8}>
      <circle cx="12" cy="12" r="3" />
      <path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-4 0v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83-2.83l.06-.06A1.65 1.65 0 0 0 4.68 15a1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1 0-4h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 2.83-2.83l.06.06A1.65 1.65 0 0 0 9 4.68a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 4 0v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 2.83l-.06.06A1.65 1.65 0 0 0 19.4 9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1z" />
    </svg>
  );
}

const TABS = [
  { id: 'home', label: 'Home', Icon: HomeIcon },
  { id: 'transactions', label: 'Transactions', Icon: ListIcon },
  { id: 'reports', label: 'Reports', Icon: ChartIcon },
  { id: 'settings', label: 'Settings', Icon: GearIcon },
];

export default function App() {
  const [tab, setTab] = useState('home');
  const store = useStore();

  if (store.loading) {
    return (
      <div className="app" style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', flexDirection: 'column', gap: 16 }}>
        <div style={{ width: 40, height: 40, border: '4px solid #e5e7eb', borderTopColor: '#6366f1', borderRadius: '50%', animation: 'spin 0.8s linear infinite' }} />
        <p style={{ color: '#6b7280', fontSize: 15 }}>Connecting to server…</p>
        <style>{`@keyframes spin { to { transform: rotate(360deg); } }`}</style>
      </div>
    );
  }

  if (store.error) {
    return (
      <div className="app" style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', flexDirection: 'column', gap: 12, padding: 24 }}>
        <p style={{ color: '#dc2626', fontWeight: 600, fontSize: 16 }}>Cannot reach backend</p>
        <p style={{ color: '#6b7280', fontSize: 13, textAlign: 'center' }}>{store.error}</p>
        <button onClick={() => window.location.reload()} style={{ padding: '8px 20px', background: '#6366f1', color: '#fff', border: 'none', borderRadius: 8, cursor: 'pointer', fontSize: 14 }}>
          Retry
        </button>
      </div>
    );
  }

  return (
    <div className="app">
      {tab === 'home' && <HomeView store={store} />}
      {tab === 'transactions' && <TransactionsView store={store} />}
      {tab === 'reports' && <ReportsView store={store} />}
      {tab === 'settings' && <SettingsView store={store} />}

      <div className="tab-bar">
        {TABS.map(({ id, label, Icon }) => (
          <button
            key={id}
            className={`tab-item ${tab === id ? 'active' : ''}`}
            onClick={() => setTab(id)}
          >
            <Icon active={tab === id} />
            {label}
          </button>
        ))}
      </div>
    </div>
  );
}
