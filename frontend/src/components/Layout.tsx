import { Outlet } from 'react-router-dom';
import { Sidebar } from './Sidebar';
import { ThemeToggle } from './ThemeToggle';
import type { Charger } from '../lib/types';

interface LayoutProps {
  chargers: Charger[];
}

export function Layout({ chargers }: LayoutProps) {
  const totalPower = chargers.reduce((sum, c) => sum + c.powerW, 0);
  const nCharging = chargers.filter((c) => c.ocppStatus === 'Charging').length;

  return (
    <div className="flex min-h-screen bg-slate-50 text-slate-800 dark:bg-slate-900 dark:text-slate-100">
      <Sidebar chargersOnline={chargers.length} />
      <main className="flex-1 overflow-y-auto p-6 max-w-6xl">
        <header className="flex items-center justify-between pb-4 mb-5 border-b border-slate-200 dark:border-slate-700">
          <div className="flex items-center gap-5">
            <span className="text-green-500 font-semibold text-sm">
              {chargers.length} online
            </span>
            <span className="text-blue-500 font-semibold text-sm">
              {nCharging} charging
            </span>
            <span className="text-slate-400 text-sm">
              {(totalPower / 1000).toFixed(1)} kW
            </span>
          </div>
          <ThemeToggle />
        </header>
        <Outlet />
      </main>
    </div>
  );
}
