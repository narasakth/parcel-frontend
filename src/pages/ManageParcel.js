import { useEffect, useState } from 'react';
import { api } from '../services/api';
import { Trash2, Star } from 'lucide-react';

export default function ManageParcel() {
  const [list, setList] = useState([]);
  const [refreshKey, setRefreshKey] = useState(0);

  // feedback states
  const [modalOpen, setModalOpen] = useState(false);
  const [targetParcel, setTargetParcel] = useState(null);
  const [rating, setRating] = useState(5);
  const [comment, setComment] = useState('');
  const [submitting, setSubmitting] = useState(false);
  const [feedbackMap, setFeedbackMap] = useState({}); // parcelId => true/false

  // โหลดรายการพัสดุ
  useEffect(() => {
    api.getParcels({ page_size: 100 }).then(d => setList(d.items || []));
  }, [refreshKey]);

  // โหลดสถานะว่าแต่ละพัสดุมี feedback แล้วหรือยัง (เฉพาะ DELIVERED)
  useEffect(() => {
    (async () => {
      const map = {};
      const delivered = (list || []).filter(p => p.status === 'DELIVERED');
      await Promise.all(
        delivered.map(async (p) => {
          try {
            const res = await requestRaw(`/feedback/parcel/${p.id}`);
            map[p.id] = !!res.exists;
          } catch {
            map[p.id] = false;
          }
        })
      );
      setFeedbackMap(map);
    })();
  }, [list]);

  const remove = async (id) => {
    if (!window.confirm('ยืนยันการลบพัสดุนี้?')) return;
    await api.deleteParcel(id);
    setRefreshKey(k => k + 1);
  };

  // ----- Feedback helpers -----
  const openFeedback = (parcel) => {
    setTargetParcel(parcel);
    setRating(5);
    setComment('');
    setModalOpen(true);
  };

  const submitFeedback = async () => {
    if (!targetParcel) return;
    setSubmitting(true);
    try {
      await requestRaw('/feedback', {
        method: 'POST',
        body: { parcel_id: targetParcel.id, rating, comment }
      });
      setModalOpen(false);
      setFeedbackMap(prev => ({ ...prev, [targetParcel.id]: true }));
    } catch (e) {
      alert(e.message || 'บันทึกไม่สำเร็จ');
    } finally {
      setSubmitting(false);
    }
  };

  // คุณจะย้ายฟังก์ชันนี้ไปไว้ใน services/api.js ก็ได้
  async function requestRaw(path, { method = 'GET', body } = {}) {
    const BASE = process.env.REACT_APP_API_BASE_URL || 'http://localhost:4000/api';
    const headers = { 'Content-Type': 'application/json' };
    const token = localStorage.getItem('accessToken');
    if (token) headers.Authorization = `Bearer ${token}`;
    const res = await fetch(`${BASE}${path}`, {
      method,
      headers,
      body: body ? JSON.stringify(body) : undefined
    });
    if (!res.ok) {
      let err = {};
      try { err = await res.json(); } catch {}
      throw new Error(err.error || res.statusText);
    }
    return res.json();
  }

  const tableCls = "min-w-full text-sm";
  const th = "px-4 py-3 text-left text-yellow-400";
  const td = "px-4 py-3";

  return (
    <div className="space-y-4">
      <h1 className="text-2xl font-extrabold text-yellow-400">Manage Parcel</h1>

      <div className="overflow-x-auto rounded-2xl border border-yellow-500/30 bg-black/60 shadow">
        <table className={tableCls}>
          <thead className="bg-black/50 border-b border-yellow-500/20">
            <tr>
              <th className={th}>Tracking</th>
              <th className={th}>ผู้รับ</th>
              <th className={th}>สถานะ</th>
              <th className={th}>ความพึงพอใจ</th>
              <th className="px-4 py-3 text-right text-yellow-400">Action</th>
            </tr>
          </thead>
          <tbody>
            {list.map(p => {
              const isDelivered = p.status === 'DELIVERED';
              const hasFeedback = !!feedbackMap[p.id];
              return (
                <tr key={p.id} className="border-t border-yellow-500/10 hover:bg-yellow-500/5">
                  <td className={td}>{p.tracking_no}</td>
                  <td className={td}>{p.receiver_name}</td>
                  <td className={td}>{p.status}</td>
                  <td className={td}>
                    {isDelivered ? (
                      hasFeedback ? (
                        <span className="inline-flex items-center px-2 py-1 rounded-lg text-xs bg-emerald-500/15 text-emerald-300 border border-emerald-500/30">
                          ได้รับคะแนนแล้ว
                        </span>
                      ) : (
                        <button
                          onClick={() => openFeedback(p)}
                          className="inline-flex items-center gap-2 rounded-lg px-3 py-1.5 bg-yellow-500 text-black hover:bg-yellow-600"
                        >
                          <Star className="w-4 h-4" /> ให้คะแนน
                        </button>
                      )
                    ) : (
                      <span className="text-gray-400 text-xs">ยังไม่ Delivered</span>
                    )}
                  </td>
                  <td className="px-4 py-3 text-right">
                    <button
                      className="inline-flex items-center gap-2 rounded-lg px-3 py-2 bg-rose-600 text-white hover:bg-rose-700"
                      onClick={() => remove(p.id)}
                    >
                      <Trash2 className="w-4 h-4" /> ลบ
                    </button>
                  </td>
                </tr>
              );
            })}
            {!list.length && (
              <tr><td className="px-4 py-6 text-center text-gray-400" colSpan="5">ไม่มีข้อมูล</td></tr>
            )}
          </tbody>
        </table>
      </div>

      {/* Modal: ให้คะแนนความพึงพอใจ */}
      {modalOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-4">
          <div className="w-full max-w-md rounded-2xl bg-black/80 border border-yellow-500/30 shadow-xl">
            <div className="px-5 py-4 border-b border-yellow-500/20 flex items-center justify-between">
              <h3 className="text-lg font-semibold text-yellow-400">ให้คะแนนความพึงพอใจ</h3>
              <button className="text-gray-300 hover:text-white" onClick={() => setModalOpen(false)}>✕</button>
            </div>

            <div className="p-5 space-y-4">
              <div className="text-sm text-gray-300">
                พัสดุ: <span className="font-semibold text-yellow-300">{targetParcel?.tracking_no}</span>
              </div>

              {/* Stars */}
              <div className="flex items-center gap-1">
                {[1,2,3,4,5].map((n) => (
                  <button
                    key={n}
                    onClick={() => setRating(n)}
                    className={`p-2 rounded-lg border ${n <= rating ? 'text-black bg-yellow-500 border-yellow-500' : 'text-yellow-400 border-yellow-500/30 hover:bg-yellow-500/10'}`}
                    aria-label={`ให้ ${n} ดาว`}
                  >
                    <Star className={`w-5 h-5 ${n <= rating ? '' : 'opacity-70'}`} />
                  </button>
                ))}
                <div className="ml-2 text-sm text-gray-300">{rating} / 5</div>
              </div>

              <div className="grid gap-1">
                <label className="text-sm text-yellow-400">ความคิดเห็น (ถ้ามี)</label>
                <textarea
                  className="min-h-[96px] rounded-lg bg-black border border-gray-700 text-gray-100 placeholder-gray-400 focus:border-yellow-400"
                  placeholder="บอกเราหน่อยว่าประสบการณ์ในการจัดส่งเป็นอย่างไรบ้าง"
                  value={comment}
                  onChange={e => setComment(e.target.value)}
                />
              </div>
            </div>

            <div className="px-5 py-4 border-t border-yellow-500/20 flex justify-end gap-2">
              <button
                className="px-4 py-2 rounded-lg bg-black/40 border border-yellow-500/30 text-yellow-300 hover:bg-yellow-500/10"
                onClick={() => setModalOpen(false)}
              >
                ยกเลิก
              </button>
              <button
                disabled={submitting}
                onClick={submitFeedback}
                className="px-4 py-2 rounded-lg bg-yellow-500 hover:bg-yellow-600 text-black font-semibold disabled:opacity-50"
              >
                {submitting ? 'กำลังบันทึก…' : 'บันทึกคะแนน'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
