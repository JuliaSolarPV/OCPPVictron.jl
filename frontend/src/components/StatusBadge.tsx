const statusColors: Record<string, string> = {
  Available: 'bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-200',
  Preparing: 'bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-200',
  Charging: 'bg-blue-100 text-blue-800 dark:bg-blue-900 dark:text-blue-200',
  SuspendedEVSE: 'bg-amber-100 text-amber-800 dark:bg-amber-900 dark:text-amber-200',
  SuspendedEV: 'bg-amber-100 text-amber-800 dark:bg-amber-900 dark:text-amber-200',
  Finishing: 'bg-amber-100 text-amber-800 dark:bg-amber-900 dark:text-amber-200',
  Faulted: 'bg-red-100 text-red-800 dark:bg-red-900 dark:text-red-200',
  Unavailable: 'bg-slate-100 text-slate-600 dark:bg-slate-700 dark:text-slate-300',
};

export function StatusBadge({ status }: { status: string }) {
  const colors = statusColors[status] ?? statusColors.Unavailable;
  return (
    <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-semibold ${colors}`}>
      {status}
    </span>
  );
}
