// All calls are relative (/api/...): nginx (compose) or the Ingress (Kubernetes) routes them to FastAPI.

async function request(path, options = {}) {
  const response = await fetch(path, {
    headers: { 'Content-Type': 'application/json' },
    ...options,
  });
  if (!response.ok) {
    let detail = `${response.status} ${response.statusText}`;
    try {
      const body = await response.json();
      if (typeof body.detail === 'string') detail = body.detail;
      else if (Array.isArray(body.detail)) detail = body.detail.map((d) => d.msg).join(', ');
    } catch {
      // non-JSON error body: keep the HTTP status text
    }
    throw new Error(detail);
  }
  return response.status === 204 ? null : response.json();
}

export const api = {
  info: () => request('/api/info'),
  stats: () => request('/api/stats'),
  items: (params) => request(`/api/items?${new URLSearchParams(params)}`),
  movements: (id) => request(`/api/items/${id}/movements`),
  create: (item) => request('/api/items', { method: 'POST', body: JSON.stringify(item) }),
  update: (id, item) => request(`/api/items/${id}`, { method: 'PUT', body: JSON.stringify(item) }),
  remove: (id) => request(`/api/items/${id}`, { method: 'DELETE' }),
  adjust: (id, delta, reason) =>
    request(`/api/items/${id}/adjust`, { method: 'POST', body: JSON.stringify({ delta, reason }) }),
};
