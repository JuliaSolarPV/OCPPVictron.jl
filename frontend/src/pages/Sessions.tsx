import { useApi } from '../hooks/useApi';
import type { Session } from '../lib/types';

export function Sessions() {
  const { data: sessions, loading } = useApi<Session[]>('/api/sessions');

  if (loading) return <div className="text-slate-400">Loading...</div>;

  return (
    <div>
      <h1 className="text-2xl font-bold mb-5">Sessions</h1>
      <div className="bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-xl p-5 shadow-sm">
        {!sessions || sessions.length === 0 ? (
          <p className="text-slate-400 text-center py-10">No charging sessions recorded yet.</p>
        ) : (
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-slate-200 dark:border-slate-700">
                <th className="text-left py-2 text-xs text-slate-400 uppercase tracking-wide">Start</th>
                <th className="text-left py-2 text-xs text-slate-400 uppercase tracking-wide">End</th>
                <th className="text-left py-2 text-xs text-slate-400 uppercase tracking-wide">Charger</th>
                <th className="text-left py-2 text-xs text-slate-400 uppercase tracking-wide">ID Tag</th>
                <th className="text-left py-2 text-xs text-slate-400 uppercase tracking-wide">Energy</th>
                <th className="text-left py-2 text-xs text-slate-400 uppercase tracking-wide">Status</th>
              </tr>
            </thead>
            <tbody>
              {sessions.map((tx) => (
                <tr key={tx.id} className="border-b border-slate-100 dark:border-slate-700/50">
                  <td className="py-2.5 text-xs">{tx.startTime}</td>
                  <td className="py-2.5 text-xs">{tx.stopTime ?? ''}</td>
                  <td className="py-2.5">{tx.chargerId}</td>
                  <td className="py-2.5">{tx.idTag ?? ''}</td>
                  <td className="py-2.5 font-semibold">
                    {tx.energyWh != null ? `${(tx.energyWh / 1000).toFixed(2)} kWh` : '-'}
                  </td>
                  <td className="py-2.5">
                    <span
                      className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-semibold ${
                        tx.status === 'active'
                          ? 'bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-200'
                          : 'bg-slate-100 text-slate-600 dark:bg-slate-700 dark:text-slate-300'
                      }`}
                    >
                      {tx.status}
                    </span>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
    </div>
  );
}
