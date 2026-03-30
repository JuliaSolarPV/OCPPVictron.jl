import { ChargerCard } from '../components/ChargerCard';
import type { Charger } from '../lib/types';

interface DashboardProps {
  chargers: Charger[];
}

export function Dashboard({ chargers }: DashboardProps) {
  const totalPower = chargers.reduce((sum, c) => sum + c.powerW, 0);
  const nCharging = chargers.filter((c) => c.ocppStatus === 'Charging').length;
  const totalEnergy = chargers.reduce((sum, c) => sum + c.energyWh, 0);

  return (
    <div>
      <h1 className="text-2xl font-bold mb-5">Dashboard</h1>

      {chargers.length === 0 ? (
        <div className="bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-xl p-10 text-center shadow-sm">
          <h3 className="text-lg font-semibold mb-2">No chargers connected</h3>
          <p className="text-slate-400">Connect an OCPP charger to see it here.</p>
        </div>
      ) : (
        <>
          {/* Stats row */}
          <div className="grid grid-cols-4 gap-4 mb-6">
            <StatCard value={String(chargers.length)} label="Online" />
            <StatCard value={String(nCharging)} label="Charging" color="text-blue-500" />
            <StatCard value={`${(totalPower / 1000).toFixed(1)} kW`} label="Total Power" />
            <StatCard value={`${(totalEnergy / 1000).toFixed(1)} kWh`} label="Total Energy" />
          </div>

          {/* Charger cards grid */}
          <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-4">
            {chargers.map((c) => (
              <ChargerCard key={c.id} charger={c} />
            ))}
          </div>
        </>
      )}
    </div>
  );
}

function StatCard({ value, label, color }: { value: string; label: string; color?: string }) {
  return (
    <div className="bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-xl p-4 text-center shadow-sm">
      <div className={`text-2xl font-bold ${color ?? ''}`}>{value}</div>
      <div className="text-xs text-slate-400 uppercase tracking-wide mt-1">{label}</div>
    </div>
  );
}
