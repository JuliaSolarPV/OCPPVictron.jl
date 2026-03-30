export interface Charger {
  id: string;
  vendor: string | null;
  model: string | null;
  serialNumber: string | null;
  firmware: string | null;
  ocppStatus: string;
  errorCode: string | null;
  powerW: number;
  currentA: number;
  energyWh: number;
  l1PowerW: number;
  l2PowerW: number;
  l3PowerW: number;
  activeTransactionId: number | null;
  transactionStartTime: string | null;
  idTag: string | null;
  connectedAt: string;
  lastSeen: string;
  serviceName: string;
  victronRegistered: boolean;
}

export interface BridgeConfig {
  ocppHost: string;
  ocppPort: number;
  ocppVersion: string;
  mqttHost: string;
  mqttPort: number;
  mqttClientId: string;
  heartbeatInterval: number;
  autoAuthorize: boolean;
  configPath: string;
  chargers: ChargerConfigEntry[];
}

export interface ChargerConfigEntry {
  chargePointId: string;
  serviceName: string;
  enabled: boolean;
}

export interface Session {
  id: number;
  chargerId: string;
  connectorId: number;
  idTag: string | null;
  startTime: string;
  stopTime: string | null;
  meterStart: number;
  meterStop: number | null;
  energyWh: number | null;
  status: string;
}

export interface LogEntry {
  timestamp: string;
  chargerId: string | null;
  level: string;
  message: string;
}

export interface BridgeStatus {
  ocppConnected: boolean;
  mqttConnected: boolean;
  chargersOnline: number;
  configPath: string;
  dbPath: string;
}

export interface MeterSample {
  timestamp: string;
  powerW: number;
  currentA: number;
  l1PowerW: number;
  l2PowerW: number;
  l3PowerW: number;
}
