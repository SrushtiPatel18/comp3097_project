import { useState, useEffect } from 'react';

const STORAGE_KEY = 'smartpocket_data';

const DEFAULT_CATEGORIES = ['Food', 'Travel', 'Entertainment', 'Utilities', 'Health', 'Shopping'];

const SEED_TRANSACTIONS = [
  { id: 1, title: 'Salary', amount: 3500, isIncome: true, categoryName: 'Income', date: '2026-03-01', note: '' },
  { id: 2, title: 'Groceries', amount: 85.40, isIncome: false, categoryName: 'Food', date: '2026-03-03', note: 'Weekly shop' },
  { id: 3, title: 'Netflix', amount: 18.99, isIncome: false, categoryName: 'Entertainment', date: '2026-03-05', note: '' },
  { id: 4, title: 'Coffee', amount: 6.50, isIncome: false, categoryName: 'Food', date: '2026-03-07', note: '' },
  { id: 5, title: 'Transit Pass', amount: 120, isIncome: false, categoryName: 'Travel', date: '2026-03-08', note: 'Monthly pass' },
];

function loadData() {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (raw) return JSON.parse(raw);
  } catch {}
  return {
    transactions: SEED_TRANSACTIONS,
    categories: DEFAULT_CATEGORIES,
    budget: 2000,
    nextId: 100,
  };
}

function saveData(data) {
  localStorage.setItem(STORAGE_KEY, JSON.stringify(data));
}

export function useStore() {
  const [data, setData] = useState(() => loadData());

  useEffect(() => {
    saveData(data);
  }, [data]);

  const addTransaction = (tx) => {
    setData(d => ({
      ...d,
      transactions: [{ ...tx, id: d.nextId }, ...d.transactions],
      nextId: d.nextId + 1,
    }));
  };

  const updateTransaction = (id, updates) => {
    setData(d => ({
      ...d,
      transactions: d.transactions.map(t => t.id === id ? { ...t, ...updates } : t),
    }));
  };

  const deleteTransaction = (id) => {
    setData(d => ({
      ...d,
      transactions: d.transactions.filter(t => t.id !== id),
    }));
  };

  const setBudget = (budget) => {
    setData(d => ({ ...d, budget: Number(budget) }));
  };

  const addCategory = (name) => {
    if (!data.categories.includes(name)) {
      setData(d => ({ ...d, categories: [...d.categories, name] }));
    }
  };

  const deleteCategory = (name) => {
    setData(d => ({
      ...d,
      categories: d.categories.filter(c => c !== name),
    }));
  };

  const resetAll = () => {
    const fresh = {
      transactions: SEED_TRANSACTIONS,
      categories: DEFAULT_CATEGORIES,
      budget: 2000,
      nextId: 100,
    };
    setData(fresh);
  };

  return {
    transactions: data.transactions,
    categories: data.categories,
    budget: data.budget,
    addTransaction,
    updateTransaction,
    deleteTransaction,
    setBudget,
    addCategory,
    deleteCategory,
    resetAll,
  };
}
