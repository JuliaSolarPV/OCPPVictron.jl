import { BrowserRouter, Routes, Route } from 'react-router-dom';
import { Layout } from './components/Layout';
import { Dashboard } from './pages/Dashboard';
import { ChargerDetail } from './pages/ChargerDetail';
import { Configuration } from './pages/Configuration';
import { Logs } from './pages/Logs';
import { Sessions } from './pages/Sessions';
import { useChargers } from './hooks/useChargers';

export default function App() {
  const { chargers } = useChargers();

  return (
    <BrowserRouter>
      <Routes>
        <Route element={<Layout chargers={chargers} />}>
          <Route path="/" element={<Dashboard chargers={chargers} />} />
          <Route path="/charger/:id" element={<ChargerDetail chargers={chargers} />} />
          <Route path="/config" element={<Configuration />} />
          <Route path="/logs" element={<Logs />} />
          <Route path="/sessions" element={<Sessions />} />
        </Route>
      </Routes>
    </BrowserRouter>
  );
}
