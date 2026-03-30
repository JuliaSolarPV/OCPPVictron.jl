import { useApi } from '../hooks/useApi';
import { useEffect } from 'react';
import type { LogEntry } from '../lib/types';

const levelColors: Record<string, string> = {
  info: 'text-green-400',
  warn: 'text-amber-400',
  error: 'text-red-400',
};

export function Logs() {
  const { data: logs, refresh } = useApi<LogEntry[]>('/api/logs');

  // Auto-refresh every 3 seconds
  useEffect(() => {
    const interval = setInterval(refresh, 3000);
    return () => clearInterval(interval);
  }, [refresh]);

  return (
    <div>
      <h1 className="text-2xl font-bold mb-5">Logs</h1>
      <div className="bg-slate-900 text-slate-200 font-mono text-xs rounded-xl p-4 max-h-[600px] overflow-y-auto leading-relaxed">
        {!logs || logs.length === 0 ? (
          <div className="text-center text-slate-500 py-10">No log entries yet.</div>
        ) : (
          logs.map((entry, i) => {
            const ts = entry.timestamp?.slice(11, 23) ?? '';
            const level = entry.level?.toUpperCase() ?? 'INFO';
            const color = levelColors[entry.level] ?? 'text-slate-400';
            return (
              <div key={i} className="py-0.5">
                <span className="text-slate-500">{ts}</span>
                <span className={`${color} font-bold mx-1.5`}>[{level}]</span>
                {entry.chargerId && (
                  <span className="text-blue-400">[{entry.chargerId}] </span>
                )}
                <span>{entry.message}</span>
              </div>
            );
          })
        )}
      </div>
    </div>
  );
}
