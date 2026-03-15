import { useState } from 'react';
import { formatCAD, formatDate, getCategoryIcon } from './utils.js';
import AddTransactionModal from './AddTransactionModal.jsx';

export default function TransactionDetailModal({ transaction: t, store, onClose }) {
  const [showEdit, setShowEdit] = useState(false);
  const [confirmDelete, setConfirmDelete] = useState(false);

  const handleDelete = () => {
    store.deleteTransaction(t.id);
    onClose();
  };

  if (showEdit) {
    return (
      <AddTransactionModal
        store={store}
        existing={t}
        onClose={() => { setShowEdit(false); onClose(); }}
      />
    );
  }

  return (
    <div className="modal-overlay" onClick={onClose}>
      <div className="modal-sheet" onClick={e => e.stopPropagation()}>
        <div className="modal-handle" />
        <div style={{ textAlign: 'center', marginBottom: 20 }}>
          <div style={{ fontSize: 48, marginBottom: 8 }}>{getCategoryIcon(t.categoryName)}</div>
          <div style={{ fontSize: 22, fontWeight: 700, color: '#1a1a2e' }}>{t.title}</div>
          <div style={{ fontSize: 28, fontWeight: 800, marginTop: 4, color: t.isIncome ? '#16a34a' : '#dc2626' }}>
            {t.isIncome ? '+' : '-'}{formatCAD(t.amount)}
          </div>
          <span className={t.isIncome ? 'tag-income' : 'tag-expense'} style={{ marginTop: 8, display: 'inline-block' }}>
            {t.isIncome ? 'Income' : 'Expense'}
          </span>
        </div>

        <div className="card" style={{ marginBottom: 16 }}>
          <div className="settings-row">
            <span className="settings-label">Category</span>
            <span className="settings-value">{t.categoryName}</span>
          </div>
          <div className="settings-row">
            <span className="settings-label">Date</span>
            <span className="settings-value">{formatDate(t.date)}</span>
          </div>
          {t.note && (
            <div className="settings-row">
              <span className="settings-label">Note</span>
              <span className="settings-value" style={{ maxWidth: '60%', textAlign: 'right' }}>{t.note}</span>
            </div>
          )}
        </div>

        <button className="btn-primary" onClick={() => setShowEdit(true)}>Edit Transaction</button>

        {!confirmDelete ? (
          <button className="confirm-btn" onClick={() => setConfirmDelete(true)}>Delete</button>
        ) : (
          <>
            <div style={{ fontSize: 13, color: '#9ca3af', textAlign: 'center', marginTop: 12 }}>
              Are you sure you want to delete this transaction?
            </div>
            <button className="confirm-btn" onClick={handleDelete}>Yes, Delete</button>
            <button className="cancel-btn" onClick={() => setConfirmDelete(false)}>Cancel</button>
          </>
        )}
      </div>
    </div>
  );
}
