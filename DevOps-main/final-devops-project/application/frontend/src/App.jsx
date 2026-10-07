import { useCallback, useEffect, useMemo, useState } from 'react';
import { api } from './api.js';
import { formatCurrency, normaliseSku, stockFill, stockStatus } from './inventory.js';

const EMPTY_FORM = { sku: '', name: '', category: 'General', location: '', quantity: 0, reorder_level: 5, unit_price: 0 };

export function App() {
  const [info, setInfo] = useState(null);
  const [stats, setStats] = useState(null);
  const [items, setItems] = useState([]);
  const [filters, setFilters] = useState({ q: '', category: '', low_stock: false });
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [editing, setEditing] = useState(null); // null | 'new' | item
  const [selected, setSelected] = useState(null);

  const refresh = useCallback(async () => {
    const params = {};
    if (filters.q) params.q = filters.q;
    if (filters.category) params.category = filters.category;
    if (filters.low_stock) params.low_stock = 'true';
    try {
      const [statsRes, itemsRes] = await Promise.all([api.stats(), api.items(params)]);
      setStats(statsRes);
      setItems(itemsRes);
      setError('');
    } catch (err) {
      setError(`Backend unavailable: ${err.message}`);
    } finally {
      setLoading(false);
    }
  }, [filters]);

  useEffect(() => {
    api.info().then(setInfo).catch(() => setInfo(null));
  }, []);

  useEffect(() => {
    const timer = setTimeout(refresh, 200);
    return () => clearTimeout(timer);
  }, [refresh]);

  const categories = useMemo(() => Object.keys(stats?.categories ?? {}).sort(), [stats]);

  const run = async (action) => {
    try {
      await action();
      await refresh();
    } catch (err) {
      setError(err.message);
    }
  };

  const adjust = (item, delta) =>
    run(async () => {
      const updated = await api.adjust(item.id, delta, delta > 0 ? 'goods received' : 'order shipped');
      if (selected?.id === item.id) setSelected(updated);
    });

  const remove = (item) => {
    if (!window.confirm(`Delete ${item.sku} (${item.name})?`)) return;
    run(async () => {
      await api.remove(item.id);
      if (selected?.id === item.id) setSelected(null);
    });
  };

  return (
    <div className="shell">
      <header className="topbar">
        <div className="brand">
          <span className="logo" aria-hidden="true">SP</span>
          <div>
            <h1>StockPilot</h1>
            <p>Inventory control for small warehouses</p>
          </div>
        </div>
        <div className="meta">
          <span className={`pill ${error ? 'pill-danger' : 'pill-ok'}`}>{error ? 'API down' : 'API healthy'}</span>
          {info && <span className="pill">{info.environment} · v{info.version}</span>}
        </div>
      </header>

      <main>
        <section className="kpis" aria-label="Inventory summary">
          <Kpi label="SKUs" value={stats?.total_skus ?? '–'} />
          <Kpi label="Units on hand" value={stats?.total_units ?? '–'} />
          <Kpi label="Inventory value" value={stats ? formatCurrency(stats.inventory_value) : '–'} />
          <Kpi label="Needs reorder" value={stats?.low_stock ?? '–'} tone="warn" />
          <Kpi label="Out of stock" value={stats?.out_of_stock ?? '–'} tone="danger" />
        </section>

        {error && <div className="alert" role="alert">{error}</div>}

        <section className="panel">
          <div className="toolbar">
            <input
              type="search"
              placeholder="Search by name or SKU"
              value={filters.q}
              onChange={(e) => setFilters({ ...filters, q: e.target.value })}
              aria-label="Search items"
            />
            <select
              value={filters.category}
              onChange={(e) => setFilters({ ...filters, category: e.target.value })}
              aria-label="Filter by category"
            >
              <option value="">All categories</option>
              {categories.map((c) => (
                <option key={c} value={c}>{c} ({stats.categories[c]})</option>
              ))}
            </select>
            <label className="toggle">
              <input
                type="checkbox"
                checked={filters.low_stock}
                onChange={(e) => setFilters({ ...filters, low_stock: e.target.checked })}
              />
              Needs reorder
            </label>
            <button className="primary" onClick={() => setEditing('new')}>+ New item</button>
          </div>

          {loading ? (
            <p className="empty">Loading inventory…</p>
          ) : items.length === 0 ? (
            <p className="empty">No items match. Add your first SKU with “New item”.</p>
          ) : (
            <table className="items">
              <thead>
                <tr>
                  <th>SKU</th><th>Item</th><th>Location</th><th>Stock</th><th>Unit price</th><th>Value</th><th>Status</th><th aria-label="Actions" />
                </tr>
              </thead>
              <tbody>
                {items.map((item) => {
                  const status = stockStatus(item);
                  return (
                    <tr key={item.id} className={selected?.id === item.id ? 'selected' : ''}>
                      <td data-label="SKU"><code>{item.sku}</code></td>
                      <td data-label="Item">
                        <button className="link" onClick={() => setSelected(item)}>{item.name}</button>
                        <small>{item.category}</small>
                      </td>
                      <td data-label="Location">{item.location}</td>
                      <td data-label="Stock">
                        <div className="stock">
                          <strong>{item.quantity}</strong>
                          <span className="bar"><span className={`fill ${status.tone}`} style={{ width: `${stockFill(item)}%` }} /></span>
                          <small>reorder at {item.reorder_level}</small>
                        </div>
                      </td>
                      <td data-label="Unit price">{formatCurrency(item.unit_price)}</td>
                      <td data-label="Value">{formatCurrency(item.quantity * item.unit_price)}</td>
                      <td data-label="Status"><span className={`badge ${status.tone}`}>{status.label}</span></td>
                      <td className="actions">
                        <button title="Ship one unit" onClick={() => adjust(item, -1)} disabled={item.quantity === 0}>−1</button>
                        <button title="Receive one unit" onClick={() => adjust(item, 1)}>+1</button>
                        <button title="Receive ten units" onClick={() => adjust(item, 10)}>+10</button>
                        <button onClick={() => setEditing(item)}>Edit</button>
                        <button className="danger" onClick={() => remove(item)}>Delete</button>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          )}
        </section>

        {selected && <Movements item={selected} onClose={() => setSelected(null)} />}
      </main>

      {editing && (
        <ItemForm
          item={editing === 'new' ? null : editing}
          onCancel={() => setEditing(null)}
          onSave={(payload) =>
            run(async () => {
              if (editing === 'new') await api.create(payload);
              else await api.update(editing.id, payload);
              setEditing(null);
            })
          }
        />
      )}
    </div>
  );
}

function Kpi({ label, value, tone = '' }) {
  return (
    <div className={`kpi ${tone}`}>
      <span>{label}</span>
      <strong>{value}</strong>
    </div>
  );
}

function Movements({ item, onClose }) {
  const [rows, setRows] = useState([]);
  useEffect(() => {
    api.movements(item.id).then(setRows).catch(() => setRows([]));
  }, [item]);
  return (
    <section className="panel movements">
      <div className="panel-head">
        <h2>Stock movements · {item.sku}</h2>
        <button onClick={onClose}>Close</button>
      </div>
      {rows.length === 0 ? (
        <p className="empty">No movements recorded yet.</p>
      ) : (
        <ul>
          {rows.map((m) => (
            <li key={m.id}>
              <span className={`delta ${m.delta > 0 ? 'in' : 'out'}`}>{m.delta > 0 ? `+${m.delta}` : m.delta}</span>
              <span>{m.reason}</span>
              <span className="muted">→ {m.quantity_after} on hand</span>
              <time className="muted">{new Date(m.created_at).toLocaleString()}</time>
            </li>
          ))}
        </ul>
      )}
    </section>
  );
}

function ItemForm({ item, onCancel, onSave }) {
  const [form, setForm] = useState(item ? { ...item } : EMPTY_FORM);
  const set = (key) => (e) => setForm({ ...form, [key]: e.target.type === 'number' ? Number(e.target.value) : e.target.value });

  const submit = (e) => {
    e.preventDefault();
    const payload = {
      name: form.name,
      category: form.category || 'General',
      location: form.location || 'Unassigned',
      reorder_level: form.reorder_level,
      unit_price: form.unit_price,
    };
    if (!item) Object.assign(payload, { sku: normaliseSku(form.sku), quantity: form.quantity });
    onSave(payload);
  };

  return (
    <div className="backdrop" role="dialog" aria-modal="true" aria-label={item ? 'Edit item' : 'New item'}>
      <form className="modal" onSubmit={submit}>
        <h2>{item ? `Edit ${item.sku}` : 'New item'}</h2>
        <div className="grid">
          <label>SKU<input required disabled={!!item} value={form.sku} onChange={set('sku')} placeholder="KB-1042" /></label>
          <label>Name<input required value={form.name} onChange={set('name')} placeholder="Mechanical keyboard" /></label>
          <label>Category<input value={form.category} onChange={set('category')} /></label>
          <label>Location<input value={form.location} onChange={set('location')} placeholder="Aisle A-01" /></label>
          {!item && <label>Opening quantity<input type="number" min="0" value={form.quantity} onChange={set('quantity')} /></label>}
          <label>Reorder level<input type="number" min="0" value={form.reorder_level} onChange={set('reorder_level')} /></label>
          <label>Unit price (₹)<input type="number" min="0" step="0.01" value={form.unit_price} onChange={set('unit_price')} /></label>
        </div>
        <div className="modal-actions">
          <button type="button" onClick={onCancel}>Cancel</button>
          <button type="submit" className="primary">Save</button>
        </div>
      </form>
    </div>
  );
}
