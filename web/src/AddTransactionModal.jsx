import { useState } from 'react';

export default function AddTransactionModal({ store, onClose, existing }) {
  const isEdit = !!existing;
  const [title, setTitle] = useState(existing?.title || '');
  const [amount, setAmount] = useState(existing ? String(existing.amount) : '');
  const [isIncome, setIsIncome] = useState(existing?.isIncome || false);
  const [category, setCategory] = useState(existing?.categoryName || (store.categories[0] || 'Food'));
  const [date, setDate] = useState(existing?.date || new Date().toISOString().slice(0, 10));
  const [note, setNote] = useState(existing?.note || '');
  const [error, setError] = useState('');

  const allCategories = store.categories;

  const canSave = title.trim() && parseFloat(amount) > 0;

  const handleSave = () => {
    if (!canSave) { setError('Please enter a title and a valid amount.'); return; }
    const tx = {
      title: title.trim(),
      amount: parseFloat(amount),
      isIncome,
      categoryName: category,
      date,
      note: note.trim(),
    };
    if (isEdit) {
      store.updateTransaction(existing.id, tx);
    } else {
      store.addTransaction(tx);
    }
    onClose();
  };

  return (
    <div className="modal-overlay" onClick={onClose}>
      <div className="modal-sheet" onClick={e => e.stopPropagation()}>
        <div className="modal-handle" />
        <div className="modal-title">{isEdit ? 'Edit Transaction' : 'Add Transaction'}</div>

        <div style={{ fontSize: 13, color: '#9ca3af', marginBottom: 16 }}>
          {isEdit ? 'Update your transaction details.' : 'Add an income or expense in a few seconds.'}
        </div>

        <div className="form-group">
          <label className="form-label">Title</label>
          <input
            className="form-input"
            placeholder="e.g., Groceries"
            value={title}
            onChange={e => setTitle(e.target.value)}
          />
        </div>

        <div className="form-group">
          <label className="form-label">Amount (CAD)</label>
          <input
            className="form-input"
            type="number"
            inputMode="decimal"
            placeholder="0.00"
            value={amount}
            onChange={e => setAmount(e.target.value)}
            min="0"
            step="0.01"
          />
        </div>

        <div className="form-group">
          <label className="form-label">Type</label>
          <div className="toggle-row">
            <span style={{ fontSize: 15, fontWeight: 500, color: isIncome ? '#16a34a' : '#dc2626' }}>
              {isIncome ? '💰 Income' : '💸 Expense'}
            </span>
            <button
              className={`toggle-switch ${isIncome ? 'on' : 'off'}`}
              onClick={() => setIsIncome(v => !v)}
            />
          </div>
        </div>

        <div className="form-group">
          <label className="form-label">Category</label>
          <select
            className="form-select"
            value={category}
            onChange={e => setCategory(e.target.value)}
          >
            {allCategories.map(c => (
              <option key={c} value={c}>{c}</option>
            ))}
          </select>
        </div>

        <div className="form-group">
          <label className="form-label">Date</label>
          <input
            className="form-input"
            type="date"
            value={date}
            onChange={e => setDate(e.target.value)}
          />
        </div>

        <div className="form-group">
          <label className="form-label">Note (optional)</label>
          <input
            className="form-input"
            placeholder="Optional note"
            value={note}
            onChange={e => setNote(e.target.value)}
          />
        </div>

        {error && (
          <div style={{ color: '#dc2626', fontSize: 13, marginBottom: 10 }}>{error}</div>
        )}

        <button className="btn-primary" onClick={handleSave} disabled={!canSave}>
          {isEdit ? 'Save Changes' : 'Save Transaction'}
        </button>
        <button className="cancel-btn" onClick={onClose}>Cancel</button>
      </div>
    </div>
  );
}
