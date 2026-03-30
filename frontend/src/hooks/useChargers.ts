import { useState, useEffect, useRef, useCallback } from 'react';
import type { Charger } from '../lib/types';

export function useChargers() {
  const [chargers, setChargers] = useState<Charger[]>([]);
  const [connected, setConnected] = useState(false);
  const wsRef = useRef<WebSocket | null>(null);
  const usingPolling = useRef(false);

  // REST fallback: poll /api/chargers every 2s if WebSocket fails
  const pollChargers = useCallback(() => {
    fetch('/api/chargers')
      .then((r) => r.json())
      .then((data) => {
        setChargers(data);
        setConnected(true);
      })
      .catch(() => setConnected(false));
  }, []);

  useEffect(() => {
    let pollInterval: ReturnType<typeof setInterval> | null = null;

    function connectWs() {
      try {
        const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
        const ws = new WebSocket(`${protocol}//${window.location.host}/api/ws`);
        wsRef.current = ws;

        ws.onopen = () => {
          setConnected(true);
          usingPolling.current = false;
          if (pollInterval) {
            clearInterval(pollInterval);
            pollInterval = null;
          }
        };

        ws.onclose = () => {
          setConnected(false);
          // Fall back to polling
          if (!usingPolling.current) {
            usingPolling.current = true;
            pollChargers();
            pollInterval = setInterval(pollChargers, 2000);
          }
          // Try WebSocket again after 10s
          setTimeout(connectWs, 10000);
        };

        ws.onerror = () => ws.close();

        ws.onmessage = (event) => {
          try {
            const msg = JSON.parse(event.data);
            if (msg.type === 'chargers') {
              setChargers(msg.data);
            }
          } catch {
            // ignore
          }
        };
      } catch {
        // WebSocket constructor failed, use polling
        if (!usingPolling.current) {
          usingPolling.current = true;
          pollChargers();
          pollInterval = setInterval(pollChargers, 2000);
        }
      }
    }

    connectWs();

    return () => {
      wsRef.current?.close();
      if (pollInterval) clearInterval(pollInterval);
    };
  }, [pollChargers]);

  return { chargers, connected };
}
