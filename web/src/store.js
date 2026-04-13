import { useState, useEffect, useCallback, useRef } from 'react';

const API = '/api';

async function apiFetch(path, options = {}) {
  const res = await fetch(`${API}${path}`, {
    ...options,
    headers: { 'Content-Type': 'application/json', ...(options.headers || {}) },
  });
  if (res.status === 204) return null;
  const text = await res.text();
  if (!text) return null;
  const json = JSON.parse(text);
  if (!res.ok) throw new Error(json.message || `HTTP ${res.status}`);
  return json;
}

// Map backend transaction → frontend transaction
function toFrontendTx(tx, categories) {
  const cat = categories.find(c => c.id === tx.categoryId);
  return {
    id: tx.id,
    title: tx.title,
    amount: tx.amount,
    isIncome: tx.type === 'income',
    categoryName: cat ? cat.name : tx.categoryId,
    categoryId: tx.categoryId,
    date: tx.date,
    note: tx.note || '',
  };
}

// Map frontend form data → backend transaction body
function toBackendTx(frontendTx, categories) {
  const cat = categories.find(c => c.name === frontendTx.categoryName);
  return {
    title: frontendTx.title,
    amount: frontendTx.amount,
    type: frontendTx.isIncome ? 'income' : 'expense',
    categoryId: cat ? cat.id : (frontendTx.categoryId || 'cat_other'),
    date: frontendTx.date,
    note: frontendTx.note || '',
  };
}

export function useStore() {
  const [transactions, setTransactions] = useState([]);
  const [categories, setCategories]     = useState([]);
  const [budget, setBudgetState]        = useState(2000);
  const [loading, setLoading]           = useState(true);
  const [error, setError]               = useState(null);
  const backendCats = useRef([]);   // raw backend category objects

  const loadAll = useCallback(async () => {
    try {
      const [rawCats, txResponse, settings] = await Promise.all([
        apiFetch('/categories'),
        apiFetch('/transactions?limit=1000'),
        apiFetch('/settings'),
      ]);
      // /transactions now returns { data: [...], meta: {...} }
      const rawTxs = Array.isArray(txResponse) ? txResponse : (txResponse?.data ?? []);
      backendCats.current = rawCats;
      const categoryNames = rawCats.map(c => c.name);
      setCategories(categoryNames);
      setTransactions(rawTxs.map(tx => toFrontendTx(tx, rawCats)));
      setBudgetState(settings.budgetLimit ?? 2000);
      setError(null);
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => { loadAll(); }, [loadAll]);

  const addTransaction = async (frontendTx) => {
    const body = toBackendTx(frontendTx, backendCats.current);
    const created = await apiFetch('/transactions', {
      method: 'POST',
      body: JSON.stringify(body),
    });
    const mapped = toFrontendTx(created, backendCats.current);
    setTransactions(prev => [mapped, ...prev]);
  };

  const updateTransaction = async (id, updates) => {
    const existing = transactions.find(t => t.id === id);
    if (!existing) return;
    const merged = { ...existing, ...updates };
    const body = toBackendTx(merged, backendCats.current);
    const updated = await apiFetch(`/transactions/${id}`, {
      method: 'PUT',
      body: JSON.stringify(body),
    });
    const mapped = toFrontendTx(updated, backendCats.current);
    setTransactions(prev => prev.map(t => t.id === id ? mapped : t));
  };

  const deleteTransaction = async (id) => {
    await apiFetch(`/transactions/${id}`, { method: 'DELETE' });
    setTransactions(prev => prev.filter(t => t.id !== id));
  };

  const setBudget = async (value) => {
    await apiFetch('/settings', {
      method: 'PUT',
      body: JSON.stringify({ budgetLimit: Number(value) }),
    });
    setBudgetState(Number(value));
  };

  const addCategory = async (name) => {
    if (backendCats.current.find(c => c.name === name)) return;
    const created = await apiFetch('/categories', {
      method: 'POST',
      body: JSON.stringify({ name, icon: 'circle', color: '#6366f1', type: 'both' }),
    });
    backendCats.current = [...backendCats.current, created];
    setCategories(prev => [...prev, name]);
  };

  const deleteCategory = async (name) => {
    const cat = backendCats.current.find(c => c.name === name);
    if (!cat) return;
    await apiFetch(`/categories/${cat.id}`, { method: 'DELETE' });
    backendCats.current = backendCats.current.filter(c => c.id !== cat.id);
    setCategories(prev => prev.filter(c => c !== name));
    setTransactions(prev =>
      prev.map(t => t.categoryName === name ? { ...t, categoryName: 'Other' } : t)
    );
  };

  const resetAll = async () => {
    const txResponse = await apiFetch('/transactions?limit=1000');
    const allTxs = Array.isArray(txResponse) ? txResponse : (txResponse?.data ?? []);
    await Promise.all(allTxs.map(tx => apiFetch(`/transactions/${tx.id}`, { method: 'DELETE' })));
    await apiFetch('/settings', {
      method: 'PUT',
      body: JSON.stringify({ budgetLimit: 2000 }),
    });
    await loadAll();
  };

  const userCategories = (backendCats.current ?? [])
    .filter(c => !c.isDefault)
    .map(c => c.name);

  return {
    transactions,
    categories,
    userCategories,
    budget,
    loading,
    error,
    addTransaction,
    updateTransaction,
    deleteTransaction,
    setBudget,
    addCategory,
    deleteCategory,
    resetAll,
  };
}
