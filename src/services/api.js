// src/services/api.js

const BASE = (process.env.REACT_APP_API_BASE_URL || 'http://localhost:4000').replace(/\/+$/, '');

function getAccessToken() {
  return localStorage.getItem('accessToken') || '';
}

function setTokens({ accessToken, refreshToken }) {
  if (accessToken) localStorage.setItem('accessToken', accessToken);
  if (refreshToken) localStorage.setItem('refreshToken', refreshToken);
}

function clearTokens() {
  localStorage.removeItem('accessToken');
  localStorage.removeItem('refreshToken');
}

async function request(path, options = {}, withAuth = true) {
  // normalize path
  let finalPath = path.replace(/^\/+/, '');
  let url = BASE;
  if (!/\/api$/.test(BASE)) url += '/api';
  url += `/${finalPath}`;

  const headers = { 'Content-Type': 'application/json', ...(options.headers || {}) };
  if (withAuth) {
    const token = getAccessToken();
    if (token) headers.Authorization = `Bearer ${token}`;
  }

  const res = await fetch(url, { ...options, headers });

  if (res.status === 401 && withAuth) {
    const ok = await tryRefresh();
    if (ok) return request(path, options, withAuth);
  }

  if (!res.ok) {
    const err = await res.json().catch(() => ({}));
    throw new Error(err.error || res.statusText || `HTTP ${res.status}`);
  }

  return res.json();
}

async function tryRefresh() {
  const rt = localStorage.getItem('refreshToken');
  if (!rt) return false;

  const refreshUrl = BASE + (BASE.endsWith('/api') ? '' : '/api') + '/auth/refresh';
  const res = await fetch(refreshUrl, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ refreshToken: rt }),
  });

  if (!res.ok) {
    clearTokens();
    return false;
  }

  const data = await res.json();
  if (data.accessToken) localStorage.setItem('accessToken', data.accessToken);
  return true;
}

export const api = {
  // Auth
  register: (body) => request('/auth/register', { method: 'POST', body: JSON.stringify(body) }, false),
  login: async (body) => {
    const data = await request('/auth/login', { method: 'POST', body: JSON.stringify(body) }, false);
    setTokens(data);
    return data;
  },
  logout: async () => {
    const rt = localStorage.getItem('refreshToken');
    if (rt) {
      await request('/auth/logout', { method: 'POST', body: JSON.stringify({ refreshToken: rt }) }, false);
    }
    clearTokens();
  },
  me: () => request('/auth/me'),

  // Parcels
  getParcels: (params = {}) => {
    const qs = new URLSearchParams(params).toString();
    return request(`/parcels${qs ? `?${qs}` : ''}`);
  },
  getParcel: (id) => request(`/parcels/${id}`),
  createParcel: (body) => request('/parcels', { method: 'POST', body: JSON.stringify(body) }),
  updateParcel: (id, body) => request(`/parcels/${id}`, { method: 'PATCH', body: JSON.stringify(body) }),
  deleteParcel: (id) => request(`/parcels/${id}`, { method: 'DELETE' }),

  // Tracking
  getTrackingList: () => request('/tracking'),
  getTrackingDetail: (id) => request(`/tracking/${id}`),
  addTrackingEvent: (id, body) => request(`/tracking/${id}/events`, { method: 'POST', body: JSON.stringify(body) }),

  // Payments
  revenue: (granularity = 'daily') => request(`/payments/summary?granularity=${granularity}`),

  // Feedback
  submitFeedback: (body) => request('/feedback', { method: 'POST', body: JSON.stringify(body) }),
  getParcelFeedback: (parcelId) => request(`/feedback/parcel/${parcelId}`),
};
