import { useState, useEffect } from 'react';

interface Stats {
  entity_count: number;
  ingestion_count: number;
  last_ingestion: {
    project_id: string;
    timestamp: string;
    function_count: number;
    library_count: number;
  } | null;
}

export default function App() {
  const [stats, setStats] = useState<Stats | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [lastRefresh, setLastRefresh] = useState<Date | null>(null);

  const API_BASE = 'http://localhost:8000';

  const fetchStats = async () => {
    setLoading(true);
    setError(null);
    try {
      const response = await fetch(`${API_BASE}/stats`);
      if (!response.ok) throw new Error(`HTTP ${response.status}`);
      const data = await response.json();
      setStats(data);
      setLastRefresh(new Date());
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Unknown error');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchStats();
    const interval = setInterval(fetchStats, 30000); // Auto-refresh every 30s
    return () => clearInterval(interval);
  }, []);

  return (
    <div style={styles.container}>
      <header style={styles.header}>
        <h1 style={styles.title}>🌐 OmniGraph Admin</h1>
        <p style={styles.subtitle}>Global Knowledge Hub Dashboard</p>
      </header>

      <main style={styles.main}>
        {/* Stats Card */}
        <div style={styles.card}>
          <h2 style={styles.cardTitle}>📊 Knowledge Graph Stats</h2>
          {loading && <p style={styles.loading}>Loading...</p>}
          {error && <p style={styles.error}>⚠️ Error: {error}</p>}
          {stats && !loading && (
            <div style={styles.statsGrid}>
              <div style={styles.statItem}>
                <span style={styles.statValue}>{stats.entity_count}</span>
                <span style={styles.statLabel}>Entities</span>
              </div>
              <div style={styles.statItem}>
                <span style={styles.statValue}>{stats.ingestion_count}</span>
                <span style={styles.statLabel}>Ingestions</span>
              </div>
            </div>
          )}
          {lastRefresh && (
            <p style={styles.refreshNote}>
              Last updated: {lastRefresh.toLocaleTimeString()}
            </p>
          )}
          <button style={styles.button} onClick={fetchStats}>
            🔄 Refresh
          </button>
        </div>

        {/* Last Ingestion Card */}
        <div style={styles.card}>
          <h2 style={styles.cardTitle}>📥 Last Ingestion</h2>
          {stats?.last_ingestion ? (
            <div style={styles.ingestInfo}>
              <p><strong>Project:</strong> {stats.last_ingestion.project_id}</p>
              <p><strong>Time:</strong> {stats.last_ingestion.timestamp}</p>
              <p><strong>Functions:</strong> {stats.last_ingestion.function_count}</p>
              <p><strong>Libraries:</strong> {stats.last_ingestion.library_count}</p>
            </div>
          ) : (
            <p style={styles.noData}>No ingestions yet.</p>
          )}
        </div>

        {/* Quick Actions */}
        <div style={styles.card}>
          <h2 style={styles.cardTitle}>⚡ Quick Actions</h2>
          <div style={styles.actionButtons}>
            <a href="http://localhost:5005" target="_blank" rel="noopener noreferrer" style={styles.actionLink}>
              Open NeoDash
            </a>
            <a href="http://localhost:7474" target="_blank" rel="noopener noreferrer" style={styles.actionLink}>
              Open Neo4j Browser
            </a>
          </div>
        </div>
      </main>

      <footer style={styles.footer}>
        <p>OmniGraph Platform Core v1.0.0</p>
      </footer>
    </div>
  );
}

const styles: Record<string, React.CSSProperties> = {
  container: {
    fontFamily: 'Inter, system-ui, sans-serif',
    minHeight: '100vh',
    backgroundColor: '#0f172a',
    color: '#e2e8f0',
    display: 'flex',
    flexDirection: 'column',
  },
  header: {
    backgroundColor: '#1e293b',
    padding: '2rem',
    textAlign: 'center',
    borderBottom: '1px solid #334155',
  },
  title: {
    fontSize: '2rem',
    fontWeight: 700,
    margin: 0,
    background: 'linear-gradient(90deg, #38bdf8, #818cf8)',
    WebkitBackgroundClip: 'text',
    WebkitTextFillColor: 'transparent',
  },
  subtitle: {
    color: '#94a3b8',
    marginTop: '0.5rem',
  },
  main: {
    flex: 1,
    padding: '2rem',
    display: 'grid',
    gridTemplateColumns: 'repeat(auto-fit, minmax(300px, 1fr))',
    gap: '1.5rem',
    maxWidth: '1200px',
    margin: '0 auto',
    width: '100%',
  },
  card: {
    backgroundColor: '#1e293b',
    borderRadius: '12px',
    padding: '1.5rem',
    border: '1px solid #334155',
    boxShadow: '0 4px 6px -1px rgba(0, 0, 0, 0.1)',
  },
  cardTitle: {
    fontSize: '1.25rem',
    fontWeight: 600,
    marginBottom: '1rem',
    color: '#f1f5f9',
  },
  statsGrid: {
    display: 'flex',
    gap: '2rem',
    marginBottom: '1rem',
  },
  statItem: {
    display: 'flex',
    flexDirection: 'column',
    alignItems: 'center',
  },
  statValue: {
    fontSize: '2.5rem',
    fontWeight: 700,
    color: '#38bdf8',
  },
  statLabel: {
    fontSize: '0.875rem',
    color: '#94a3b8',
  },
  loading: {
    color: '#94a3b8',
  },
  error: {
    color: '#f87171',
  },
  noData: {
    color: '#64748b',
  },
  refreshNote: {
    fontSize: '0.75rem',
    color: '#64748b',
    marginBottom: '1rem',
  },
  button: {
    backgroundColor: '#3b82f6',
    color: 'white',
    border: 'none',
    padding: '0.5rem 1rem',
    borderRadius: '6px',
    cursor: 'pointer',
    fontWeight: 500,
  },
  ingestInfo: {
    fontSize: '0.875rem',
    lineHeight: 1.8,
  },
  actionButtons: {
    display: 'flex',
    flexDirection: 'column',
    gap: '0.75rem',
  },
  actionLink: {
    display: 'block',
    backgroundColor: '#334155',
    color: '#e2e8f0',
    padding: '0.75rem 1rem',
    borderRadius: '6px',
    textDecoration: 'none',
    textAlign: 'center',
    transition: 'background-color 0.2s',
  },
  footer: {
    textAlign: 'center',
    padding: '1rem',
    color: '#64748b',
    fontSize: '0.75rem',
  },
};
