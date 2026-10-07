// Pure helpers shared by the UI (unit-tested with `node --test`).

const currency = new Intl.NumberFormat('en-IN', { style: 'currency', currency: 'INR', maximumFractionDigits: 2 });

export const formatCurrency = (value) => currency.format(Number(value) || 0);

export function stockStatus(item) {
  if (item.quantity === 0) return { label: 'Out of stock', tone: 'danger' };
  if (item.quantity <= item.reorder_level) return { label: 'Reorder', tone: 'warn' };
  return { label: 'In stock', tone: 'ok' };
}

// Fill level of the stock bar: full at 3x the reorder level.
export function stockFill(item) {
  const target = Math.max(item.reorder_level * 3, 1);
  return Math.min(100, Math.round((item.quantity / target) * 100));
}

export function normaliseSku(raw) {
  return raw.trim().toUpperCase().replace(/\s+/g, '-');
}
