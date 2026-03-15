import { useState } from 'react';
import { PieChart, Pie, Cell, Tooltip, ResponsiveContainer, Legend } from 'recharts';
import { formatCAD, getChartColor } from './utils.js';

function CalendarView({ transactions }) {
  const [selectedDate, setSelectedDate] = useState(new Date().toISOString().slice(0, 10));

  const dayTxs = transactions.filter(t => t.date === selectedDate)
    .sort((a, b) => new Date(b.date) - new Date(a.date));

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
      <div className="card">
        <div className="section-title">Calendar View</div>
        <div className="form-group">
          <label className="form-label">Select Date</label>
          <input
            className="form-input"
            type="date"
            value={selectedDate}
            onChange={e => setSelectedDate(e.target.value)}
          />
        </div>

        <div style={{ fontSize: 13, color: '#9ca3af', marginBottom: 8 }}>
          Transactions on {new Date(selectedDate + 'T12:00:00').toLocaleDateString('en-CA', { month: 'long', day: 'numeric', year: 'numeric' })}
        </div>

        {dayTxs.length === 0 ? (
          <div className="empty-state" style={{ padding: '16px 0' }}>No transactions on this date.</div>
        ) : (
          dayTxs.map(t => (
            <div key={t.id} className="tx-row">
              <div className="tx-info">
                <div className="tx-title">{t.title}</div>
                <div className="tx-meta">{t.categoryName}</div>
              </div>
              <div className={`tx-amount ${t.isIncome ? 'income' : 'expense'}`}>
                {t.isIncome ? '+' : '-'}{formatCAD(t.amount)}
              </div>
            </div>
          ))
        )}
      </div>
    </div>
  );
}

function ByCategoryView({ transactions }) {
  const expenses = transactions.filter(t => !t.isIncome);
  const totals = {};
  expenses.forEach(t => {
    totals[t.categoryName] = (totals[t.categoryName] || 0) + t.amount;
  });
  const data = Object.entries(totals)
    .map(([category, total]) => ({ category, total }))
    .sort((a, b) => b.total - a.total);

  const total = data.reduce((s, d) => s + d.total, 0);

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
      <div className="card">
        <div className="section-title">Spending by Category</div>

        {data.length === 0 ? (
          <div className="empty-state">No expense transactions yet.</div>
        ) : (
          <>
            <ResponsiveContainer width="100%" height={240}>
              <PieChart>
                <Pie
                  data={data}
                  dataKey="total"
                  nameKey="category"
                  cx="50%"
                  cy="50%"
                  innerRadius={65}
                  outerRadius={100}
                >
                  {data.map((entry, index) => (
                    <Cell key={entry.category} fill={getChartColor(index)} />
                  ))}
                </Pie>
                <Tooltip formatter={(v) => formatCAD(v)} />
              </PieChart>
            </ResponsiveContainer>

            <div style={{ height: 1, background: '#e5e7eb', margin: '12px 0' }} />

            {data.map((item, i) => (
              <div key={item.category} style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '8px 0', borderBottom: '1px solid rgba(0,0,0,0.05)' }}>
                <div style={{ width: 10, height: 10, borderRadius: 5, background: getChartColor(i), flexShrink: 0 }} />
                <span style={{ flex: 1, fontSize: 15, color: '#1a1a2e' }}>{item.category}</span>
                <div style={{ textAlign: 'right' }}>
                  <div style={{ fontSize: 15, fontWeight: 600, color: '#6b7280' }}>{formatCAD(item.total)}</div>
                  <div style={{ fontSize: 11, color: '#9ca3af' }}>{total > 0 ? Math.round(item.total / total * 100) : 0}%</div>
                </div>
              </div>
            ))}
          </>
        )}
      </div>
    </div>
  );
}

export default function ReportsView({ store }) {
  const [mode, setMode] = useState('category');

  return (
    <div className="main-content">
      <h1 className="page-header">Reports</h1>

      <div className="chip-row">
        <button
          className={`chip ${mode === 'category' ? 'active' : ''}`}
          onClick={() => setMode('category')}
        >
          By Category
        </button>
        <button
          className={`chip ${mode === 'calendar' ? 'active' : ''}`}
          onClick={() => setMode('calendar')}
        >
          Calendar View
        </button>
      </div>

      {mode === 'category' ? (
        <ByCategoryView transactions={store.transactions} />
      ) : (
        <CalendarView transactions={store.transactions} />
      )}
    </div>
  );
}
