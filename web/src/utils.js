export function formatCAD(amount) {
  return new Intl.NumberFormat('en-CA', {
    style: 'currency',
    currency: 'CAD',
    minimumFractionDigits: 2,
  }).format(amount);
}

export function formatDate(dateStr) {
  const d = new Date(dateStr);
  return d.toLocaleDateString('en-CA', { month: 'short', day: 'numeric', year: 'numeric' });
}

export function formatDateShort(dateStr) {
  const d = new Date(dateStr);
  return d.toLocaleDateString('en-CA', { month: 'short', day: 'numeric' });
}

export const CATEGORY_ICONS = {
  Food: '🍔',
  Travel: '✈️',
  Entertainment: '🎬',
  Utilities: '💡',
  Health: '💊',
  Shopping: '🛍️',
  Income: '💰',
  Other: '📦',
};

export function getCategoryIcon(cat) {
  return CATEGORY_ICONS[cat] || '📦';
}

const CHART_COLORS = [
  '#7c3aed', '#3b82f6', '#f59e0b', '#10b981',
  '#ef4444', '#ec4899', '#06b6d4', '#84cc16',
];

export function getChartColor(index) {
  return CHART_COLORS[index % CHART_COLORS.length];
}
