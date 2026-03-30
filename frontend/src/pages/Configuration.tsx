import { useApi } from '../hooks/useApi';
import type { BridgeConfig } from '../lib/types';

export function Configuration() {
  const { data: config, loading, refresh } = useApi<BridgeConfig>('/api/config');

  if (loading || !config) return <div className="text-slate-400">Loading...</div>;

  return (
    <div>
      <h1 className="text-2xl font-bold mb-5">Configuration</h1>

      {/* Bridge Settings */}
      <div className="bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-xl p-5 shadow-sm mb-4">
        <h3 className="text-base font-semibold mb-3">Bridge Settings</h3>
        <div className="grid grid-cols-2 gap-3 text-sm">
          <Field label="OCPP Host" value={config.ocppHost} />
          <Field label="OCPP Port" value={String(config.ocppPort)} />
          <Field label="Version" value={config.ocppVersion} />
          <Field label="Heartbeat" value={`${config.heartbeatInterval}s`} />
          <Field label="MQTT Host" value={config.mqttHost} />
          <Field label="MQTT Port" value={String(config.mqttPort)} />
          <Field label="Client ID" value={config.mqttClientId} />
          <Field label="Auto-authorize" value={config.autoAuthorize ? 'Yes' : 'No'} />
        </div>
      </div>

      {/* Chargers */}
      <div className="bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-xl p-5 shadow-sm mb-4">
        <h3 className="text-base font-semibold mb-1">Known Chargers</h3>
        <p className="text-xs text-slate-400 mb-3">
          Chargers are auto-added when they first connect.
        </p>
        {config.chargers.length === 0 ? (
          <p className="text-slate-400 text-sm">No chargers configured yet.</p>
        ) : (
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-slate-200 dark:border-slate-700">
                <th className="text-left py-2 text-xs text-slate-400 uppercase tracking-wide">Charge Point ID</th>
                <th className="text-left py-2 text-xs text-slate-400 uppercase tracking-wide">Service Name</th>
                <th className="text-left py-2 text-xs text-slate-400 uppercase tracking-wide">Status</th>
              </tr>
            </thead>
            <tbody>
              {config.chargers.map((c) => (
                <tr key={c.chargePointId} className="border-b border-slate-100 dark:border-slate-700/50">
                  <td className="py-2">{c.chargePointId}</td>
                  <td className="py-2">{c.serviceName}</td>
                  <td className="py-2">
                    <span className={c.enabled ? 'text-green-500 font-semibold' : 'text-slate-400'}>
                      {c.enabled ? 'Enabled' : 'Disabled'}
                    </span>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>

      {/* Config file */}
      <div className="bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-xl p-5 shadow-sm">
        <div className="flex justify-between items-center">
          <span className="text-xs text-slate-400">Config: {config.configPath}</span>
          <button
            onClick={() => {
              fetch('/api/config/reload', { method: 'POST' })
                .then(() => refresh())
                .catch(() => {});
            }}
            className="px-3 py-1.5 text-sm rounded-lg border border-slate-200 dark:border-slate-600 hover:bg-slate-100 dark:hover:bg-slate-700 transition-colors"
          >
            Reload Config
          </button>
        </div>
      </div>
    </div>
  );
}

function Field({ label, value }: { label: string; value: string }) {
  return (
    <div>
      <span className="text-slate-400">{label}:</span>{' '}
      <span>{value}</span>
    </div>
  );
}
