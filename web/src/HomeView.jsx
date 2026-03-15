import { useState } from 'react';
import { formatCAD, formatDateShort, getCategoryIcon } from './utils.js';
import AddTransactionModal from './AddTransactionModal.jsx';
import TransactionDetailModal from './TransactionDetailModal.jsx';

export default function HomeView({ store }) {
  const [showAdd, setShowAdd] = useState(false);
  const [selected, setSelected] = useState(null);

  const { transactions, budget } = store;
  const currentMonth = new Date().getMonth();
  const currentYear = new Date().getFullYear();

  const monthTxs = transactions.filter(t => {
    const d = new Date(t.date);
    return d.getMonth() === currentMonth && d.getFullYear() === currentYear;
  });

  const spent = monthTxs.filter(t => !t.isIncome).reduce((s, t) => s + t.amount, 0);
  const income = monthTxs.filter(t => t.isIncome).reduce((s, t) => s + t.amount, 0);
  const remaining = Math.max(budget - spent, 0);
  const progress = Math.min(spent / Math.max(budget, 1), 1);
  const recent = [...transactions].sort((a, b) => new Date(b.date) - new Date(a.date)).slice(0, 4);

  return (
    <div className="main-content">
      <h1 className="page-header">Home</h1>

      <div style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
        <div className="card">
          <div style={{ fontSize: 13, color: '#9ca3af', fontWeight: 500, marginBottom: 4 }}>Welcome, Samantha!</div>
          <div style={{ fontSize: 18, fontWeight: 700, color: '#1a1a2e', marginBottom: 12 }}>Monthly Budget</div>

          <div style={{ display: 'flex', alignItems: 'baseline', gap: 6, marginBottom: 8 }}>
            <span style={{ fontSize: 26, fontWeight: 700, color: '#1a1a2e' }}>{formatCAD(spent)}</span>
            <span style={{ fontSize: 14, color: '#9ca3af' }}>/ {formatCAD(budget)}</span>
          </div>

          <div className="progress-bar">
            <div className="progress-fill" style={{ width: `${progress * 100}%` }} />
          </div>

          <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginTop: 6 }}>
            <span style={{ fontSize: 16 }}>✨</span>
            <span style={{ fontSize: 13, color: '#9ca3af' }}>
              You have <strong style={{ color: '#7c3aed' }}>{formatCAD(remaining)}</strong> remaining
            </span>
          </div>
        </div>

        <div className="card">
          <div style={{ display: 'flex', gap: 0 }}>
            <div style={{ flex: 1, textAlign: 'center' }}>
              <div style={{ fontSize: 12, color: '#9ca3af', marginBottom: 4 }}>Income</div>
              <div style={{ fontSize: 18, fontWeight: 700, color: '#16a34a' }}>{formatCAD(income)}</div>
            </div>
            <div style={{ width: 1, background: '#e5e7eb', margin: '0 8px' }} />
            <div style={{ flex: 1, textAlign: 'center' }}>
              <div style={{ fontSize: 12, color: '#9ca3af', marginBottom: 4 }}>Spent</div>
              <div style={{ fontSize: 18, fontWeight: 700, color: '#dc2626' }}>{formatCAD(spent)}</div>
            </div>
            <div style={{ width: 1, background: '#e5e7eb', margin: '0 8px' }} />
            <div style={{ flex: 1, textAlign: 'center' }}>
              <div style={{ fontSize: 12, color: '#9ca3af', marginBottom: 4 }}>Saved</div>
              <div style={{ fontSize: 18, fontWeight: 700, color: '#7c3aed' }}>{formatCAD(Math.max(income - spent, 0))}</div>
            </div>
          </div>
        </div>

        <div className="card">
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 10 }}>
            <span className="section-title" style={{ marginBottom: 0 }}>Recent Transactions</span>
          </div>

          {recent.length === 0 ? (
            <div className="empty-state">No transactions yet.<br />Tap + to add one.</div>
          ) : (
            recent.map(t => (
              <div key={t.id} className="tx-row" onClick={() => setSelected(t)}>
                <div className={`tx-icon ${t.isIncome ? 'income' : 'expense'}`}>
                  {getCategoryIcon(t.categoryName)}
                </div>
                <div className="tx-info">
                  <div className="tx-title">{t.title}</div>
                  <div className="tx-meta">{t.categoryName} · {formatDateShort(t.date)}</div>
                </div>
                <div className={`tx-amount ${t.isIncome ? 'income' : 'expense'}`}>
                  {t.isIncome ? '+' : '-'}{formatCAD(t.amount)}
                </div>
              </div>
            ))
          )}
        </div>
      </div>

      <button className="fab" onClick={() => setShowAdd(true)}>+</button>

      {showAdd && (
        <AddTransactionModal
          store={store}
          onClose={() => setShowAdd(false)}
        />
      )}

      {selected && (
        <TransactionDetailModal
          transaction={selected}
          store={store}
          onClose={() => setSelected(null)}
        />
      )}
    </div>
  );
}
