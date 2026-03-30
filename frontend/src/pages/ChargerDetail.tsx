import { useParams, useNavigate } from 'react-router-dom';
import { useEffect, useState } from 'react';
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer } from 'recharts';
import { StatusBadge } from '../components/StatusBadge';
import type { Charger, MeterSample } from '../lib/types';

interface ChargerDetailProps {
  chargers: Charger[];
}

export function ChargerDetail({ chargers }: ChargerDetailProps) {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const charger = chargers.find((c) => c.id === id);
  const [history, setHistory] = useState<MeterSample[]>([]);

  useEffect(() => {
    if (!id) return;
    const fetchHistory = () => {
      fetch(`/api/chargers/${id}/history`)
        .then((r) => r.json())
        .then(setHistory)
        .catch(() => {});
    };
    fetchHistory();
    const interval = setInterval(fetchHistory, 3000);
    return () => clearInterval(interval);
  }, [id]);

  if (!charger) {
    return (
      <div>
        <button onClick={() => navigate('/')} className="text-blue-500 font-semibold text-sm mb-4 hover:underline">
          &larr; Back to Overview
        </button>
        <div className="bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-xl p-10 text-center">
          <p className="text-slate-400">Charger {id} not connected.</p>
        </div>
      </div>
    );
  }

  const powerKw = (charger.powerW / 1000).toFixed(2);
  const energyKwh = (charger.energyWh / 1000).toFixed(1);

  const chartData = history.map((s, i) => ({
    t: -(history.length - 1 - i),
    power: +(s.powerW / 1000).toFixed(2),
    current: +s.currentA.toFixed(1),
    l1: +(s.l1PowerW / 1000).toFixed(2),
    l2: +(s.l2PowerW / 1000).toFixed(2),
    l3: +(s.l3PowerW / 1000).toFixed(2),
  }));

  return (
    <div>
      <button onClick={() => navigate('/')} className="text-blue-500 font-semibold text-sm mb-4 hover:underline">
        &larr; Back to Overview
      </button>

      {/* Identity */}
      <div className="bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-xl p-5 shadow-sm mb-4">
        <div className="flex justify-between items-center mb-3">
          <h2 className="text-xl font-bold">{charger.id}</h2>
          <StatusBadge status={charger.ocppStatus} />
        </div>
        <div className="grid grid-cols-2 gap-2 text-sm">
          <div><span className="text-slate-400">Vendor:</span> {charger.vendor ?? 'Unknown'}</div>
          <div><span className="text-slate-400">Model:</span> {charger.model ?? 'Unknown'}</div>
          <div><span className="text-slate-400">Serial:</span> {charger.serialNumber ?? 'N/A'}</div>
          <div><span className="text-slate-400">Firmware:</span> {charger.firmware ?? 'N/A'}</div>
        </div>
      </div>

      {/* Metrics */}
      <div className="bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-xl p-5 shadow-sm mb-4">
        <div className="flex justify-center gap-10">
          <div className="text-center">
            <div className="text-4xl font-bold">{powerKw}</div>
            <div className="text-sm text-slate-400">kW</div>
          </div>
          <div className="text-center">
            <div className="text-2xl font-semibold">{charger.currentA.toFixed(1)} A</div>
            <div className="text-sm text-slate-400">Current</div>
          </div>
          <div className="text-center">
            <div className="text-2xl font-semibold">{energyKwh} kWh</div>
            <div className="text-sm text-slate-400">Energy</div>
          </div>
        </div>
      </div>

      {/* Charts */}
      {chartData.length > 0 && (
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-4 mb-4">
          <div className="bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-xl p-5 shadow-sm">
            <h3 className="text-sm font-semibold mb-3">Power (kW)</h3>
            <ResponsiveContainer width="100%" height={250}>
              <LineChart data={chartData}>
                <CartesianGrid strokeDasharray="3 3" stroke="#334155" />
                <XAxis dataKey="t" stroke="#64748b" fontSize={11} />
                <YAxis stroke="#64748b" fontSize={11} />
                <Tooltip />
                <Legend />
                <Line type="monotone" dataKey="power" stroke="#3b82f6" strokeWidth={2} dot={false} name="Total" />
                <Line type="monotone" dataKey="l1" stroke="#ef4444" strokeWidth={1} dot={false} name="L1" />
                <Line type="monotone" dataKey="l2" stroke="#22c55e" strokeWidth={1} dot={false} name="L2" />
                <Line type="monotone" dataKey="l3" stroke="#f59e0b" strokeWidth={1} dot={false} name="L3" />
              </LineChart>
            </ResponsiveContainer>
          </div>
          <div className="bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-xl p-5 shadow-sm">
            <h3 className="text-sm font-semibold mb-3">Current (A)</h3>
            <ResponsiveContainer width="100%" height={250}>
              <LineChart data={chartData}>
                <CartesianGrid strokeDasharray="3 3" stroke="#334155" />
                <XAxis dataKey="t" stroke="#64748b" fontSize={11} />
                <YAxis stroke="#64748b" fontSize={11} />
                <Tooltip />
                <Line type="monotone" dataKey="current" stroke="#3b82f6" strokeWidth={2} dot={false} name="Current" />
              </LineChart>
            </ResponsiveContainer>
          </div>
        </div>
      )}

      {/* Victron info */}
      <div className="bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-xl p-5 shadow-sm">
        <h3 className="text-sm font-semibold mb-2">Victron Integration</h3>
        <div className="flex gap-6 text-sm">
          <div>Service: <strong>{charger.serviceName}</strong></div>
          <div>
            Status:{' '}
            <span className={charger.victronRegistered ? 'text-green-500 font-semibold' : 'text-slate-400'}>
              {charger.victronRegistered ? 'Registered' : 'Not registered'}
            </span>
          </div>
        </div>
      </div>
    </div>
  );
}
