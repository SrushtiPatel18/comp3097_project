import { useState } from 'react';
import { formatCAD } from './utils.js';

export default function SettingsView({ store }) {
  const [editBudget, setEditBudget] = useState(false);
  const [budgetInput, setBudgetInput] = useState(String(store.budget));
  const [newCat, setNewCat] = useState('');
  const [confirmReset, setConfirmReset] = useState(false);

  const handleSaveBudget = () => {
    const v = parseFloat(budgetInput);
    if (v > 0) { store.setBudget(v); setEditBudget(false); }
  };

  const handleAddCat = () => {
    const name = newCat.trim();
    if (name) { store.addCategory(name); setNewCat(''); }
  };

  return (
    <div className="main-content">
      <h1 className="page-header">Settings</h1>

      <div style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
        <div className="card">
          <div className="section-title">Budget</div>
          {editBudget ? (
            <>
              <div className="form-group">
                <label className="form-label">Monthly Budget (CAD)</label>
                <input
                  className="form-input"
                  type="number"
                  inputMode="decimal"
                  value={budgetInput}
                  onChange={e => setBudgetInput(e.target.value)}
                  min="1"
                />
              </div>
              <div style={{ display: 'flex', gap: 8 }}>
                <button className="btn-primary" onClick={handleSaveBudget} style={{ flex: 1 }}>Save</button>
                <button className="cancel-btn" onClick={() => setEditBudget(false)} style={{ flex: 1, marginTop: 0 }}>Cancel</button>
              </div>
            </>
          ) : (
            <div className="settings-row">
              <span className="settings-label">Monthly Budget</span>
              <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                <span className="settings-value">{formatCAD(store.budget)}</span>
                <button
                  onClick={() => { setBudgetInput(String(store.budget)); setEditBudget(true); }}
                  style={{ background: '#ede9fe', color: '#7c3aed', border: 'none', borderRadius: 8, padding: '4px 10px', fontSize: 13, fontWeight: 600, cursor: 'pointer', fontFamily: 'inherit' }}
                >
                  Edit
                </button>
              </div>
            </div>
          )}
        </div>

        <div className="card">
          <div className="section-title">Categories</div>

          {store.categories.map(c => (
            <div key={c} className="settings-row">
              <span className="settings-label">{c}</span>
              <button
                className="delete-btn"
                onClick={() => store.deleteCategory(c)}
                title="Delete category"
              >
                ×
              </button>
            </div>
          ))}

          <div style={{ marginTop: 14, display: 'flex', gap: 8 }}>
            <input
              className="form-input"
              placeholder="New category name"
              value={newCat}
              onChange={e => setNewCat(e.target.value)}
              onKeyDown={e => e.key === 'Enter' && handleAddCat()}
              style={{ flex: 1 }}
            />
            <button
              onClick={handleAddCat}
              disabled={!newCat.trim()}
              style={{
                background: newCat.trim() ? 'linear-gradient(135deg, #7c3aed, #3b82f6)' : '#e5e7eb',
                color: newCat.trim() ? 'white' : '#9ca3af',
                border: 'none', borderRadius: 12, padding: '0 18px',
                fontWeight: 600, cursor: newCat.trim() ? 'pointer' : 'default',
                fontSize: 15, fontFamily: 'inherit',
              }}
            >
              Add
            </button>
          </div>
        </div>

        <div className="card">
          <div className="section-title">Data</div>
          <div style={{ fontSize: 14, color: '#9ca3af', marginBottom: 14 }}>
            Reset all transaction data and restore default categories. Your budget setting will be reset to $2,000 CAD.
          </div>

          {!confirmReset ? (
            <button className="confirm-btn" onClick={() => setConfirmReset(true)}>
              Reset All Data
            </button>
          ) : (
            <>
              <div style={{ fontSize: 14, color: '#92400e', background: '#fef3c7', borderRadius: 10, padding: '10px 14px', marginBottom: 10 }}>
                This will delete all transactions and reset settings. Are you sure?
              </div>
              <button className="confirm-btn" onClick={() => { store.resetAll(); setConfirmReset(false); }}>
                Yes, Reset Everything
              </button>
              <button className="cancel-btn" onClick={() => setConfirmReset(false)}>Cancel</button>
            </>
          )}
        </div>
      </div>
    </div>
  );
}
