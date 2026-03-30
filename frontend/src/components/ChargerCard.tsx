import { useNavigate } from 'react-router-dom';
import { StatusBadge } from './StatusBadge';
import type { Charger } from '../lib/types';

function formatTime(startTime: string | null): string {
  if (!startTime) return '--:--:--';
  const secs = Math.floor((Date.now() - new Date(startTime).getTime()) / 1000);
  const h = Math.floor(secs / 3600);
  const m = Math.floor((secs % 3600) / 60);
  const s = secs % 60;
  return `${String(h).padStart(2, '0')}:${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`;
}

export function ChargerCard({ charger }: { charger: Charger }) {
  const navigate = useNavigate();
  const powerKw = (charger.powerW / 1000).toFixed(2);
  const energyKwh = (charger.energyWh / 1000).toFixed(1);
  const l1 = (charger.l1PowerW / 1000).toFixed(1);
  const l2 = (charger.l2PowerW / 1000).toFixed(1);
  const l3 = (charger.l3PowerW / 1000).toFixed(1);

  return (
    <div
      onClick={() => navigate(`/charger/${charger.id}`)}
      className="bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-xl p-5 cursor-pointer shadow-sm hover:border-blue-500 hover:shadow-md transition-all"
    >
      {/* Header */}
      <div className="flex justify-between items-center mb-3">
        <span className="font-semibold text-sm">{charger.id}</span>
        <StatusBadge status={charger.ocppStatus} />
      </div>

      {/* Power */}
      <div className="text-center my-4">
        <span className="text-4xl font-bold">{powerKw}</span>
        <span className="text-lg text-slate-400 ml-1">kW</span>
      </div>

      {/* Metrics row */}
      <div className="flex justify-center gap-6 text-sm">
        <div className="text-center">
          <div className="font-semibold">{charger.currentA.toFixed(1)} A</div>
          <div className="text-xs text-slate-400 uppercase tracking-wide">Current</div>
        </div>
        <div className="text-center">
          <div className="font-semibold">{energyKwh} kWh</div>
          <div className="text-xs text-slate-400 uppercase tracking-wide">Energy</div>
        </div>
        <div className="text-center">
          <div className="font-semibold">{formatTime(charger.transactionStartTime)}</div>
          <div className="text-xs text-slate-400 uppercase tracking-wide">Time</div>
        </div>
      </div>

      {/* Phase power */}
      <div className="flex justify-center gap-4 mt-3 text-xs text-slate-400">
        <span>L1: {l1} kW</span>
        <span>L2: {l2} kW</span>
        <span>L3: {l3} kW</span>
      </div>

      {/* Footer */}
      <div className="flex justify-between mt-3 text-xs text-slate-400">
        <span>{charger.idTag ?? ''}</span>
        <span>{charger.serviceName}</span>
      </div>
    </div>
  );
}
