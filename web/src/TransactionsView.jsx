import { useState } from 'react';
import { formatCAD, formatDateShort, getCategoryIcon } from './utils.js';
import AddTransactionModal from './AddTransactionModal.jsx';
import TransactionDetailModal from './TransactionDetailModal.jsx';

export default function TransactionsView({ store }) {
  const [filter, setFilter] = useState('all');
  const [search, setSearch] = useState('');
  const [showAdd, setShowAdd] = useState(false);
  const [selected, setSelected] = useState(null);

  const filtered = store.transactions
    .filter(t => {
      if (filter === 'income' && !t.isIncome) return false;
      if (filter === 'expenses' && t.isIncome) return false;
      const q = search.trim().toLowerCase();
      if (q && !t.title.toLowerCase().includes(q) && !t.categoryName.toLowerCase().includes(q)) return false;
      return true;
    })
    .sort((a, b) => new Date(b.date) - new Date(a.date));

  return (
    <div className="main-content">
      <h1 className="page-header">Transactions</h1>

      <div className="search-wrapper">
        <span className="search-icon">
          <svg width="16" height="16" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
            <circle cx="11" cy="11" r="8" /><path d="m21 21-4.35-4.35" />
          </svg>
        </span>
        <input
          className="search-input"
          placeholder="Search title or category"
          value={search}
          onChange={e => setSearch(e.target.value)}
        />
      </div>

      <div className="chip-row">
        {['all', 'expenses', 'income'].map(f => (
          <button
            key={f}
            className={`chip ${filter === f ? 'active' : ''}`}
            onClick={() => setFilter(f)}
          >
            {f.charAt(0).toUpperCase() + f.slice(1)}
          </button>
        ))}
      </div>

      <div className="card">
        {filtered.length === 0 ? (
          <div className="empty-state">
            {search ? 'No results found.' : 'No transactions yet.\nTap + to add one.'}
          </div>
        ) : (
          filtered.map(t => (
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

      <button className="fab" onClick={() => setShowAdd(true)}>+</button>

      {showAdd && (
        <AddTransactionModal store={store} onClose={() => setShowAdd(false)} />
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
