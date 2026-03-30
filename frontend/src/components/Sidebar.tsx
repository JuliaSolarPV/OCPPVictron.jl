import { NavLink } from 'react-router-dom';

const navItems = [
  { to: '/', label: 'Dashboard' },
  { to: '/config', label: 'Configuration' },
  { to: '/logs', label: 'Logs' },
  { to: '/sessions', label: 'Sessions' },
];

interface SidebarProps {
  chargersOnline: number;
}

export function Sidebar({ chargersOnline }: SidebarProps) {
  return (
    <aside className="w-56 bg-slate-800 flex flex-col min-h-screen border-r border-slate-700">
      <div className="text-white text-lg font-bold px-5 py-4 border-b border-slate-700">
        OCPPVictron
      </div>
      <nav className="flex-1 pt-1">
        {navItems.map(({ to, label }) => (
          <NavLink
            key={to}
            to={to}
            end={to === '/'}
            className={({ isActive }) =>
              `block px-5 py-2.5 text-sm border-l-3 transition-colors ${
                isActive
                  ? 'border-blue-500 bg-blue-500/15 text-white font-semibold'
                  : 'border-transparent text-slate-400 hover:text-white hover:bg-white/5'
              }`
            }
          >
            {label}
          </NavLink>
        ))}
      </nav>
      <div className="px-5 py-3 text-xs text-slate-500 flex items-center gap-1.5">
        <span
          className={`inline-block w-2 h-2 rounded-full ${
            chargersOnline > 0 ? 'bg-green-500' : 'bg-gray-500'
          }`}
        />
        {chargersOnline > 0
          ? `${chargersOnline} charger${chargersOnline === 1 ? '' : 's'} online`
          : 'No chargers'}
      </div>
    </aside>
  );
}
