import { useState, useEffect } from 'react';

export default function Health() {
  const [healthData, setHealthData] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    fetchHealth();
  }, []);

  const fetchHealth = async () => {
    try {
      setLoading(true);
      const apiUrl = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8080';
      const response = await fetch(`${apiUrl}/health`);
      
      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`);
      }
      
      const data = await response.json();
      setHealthData(data);
      setError(null);
    } catch (err) {
      setError(err.message);
      setHealthData(null);
    } finally {
      setLoading(false);
    }
  };

  const getStatusColor = (status) => {
    switch (status) {
      case 'ok': return '#10b981';
      case 'degraded': return '#f59e0b';
      case 'no_database': return '#ef4444';
      default: return '#6b7280';
    }
  };

  const getStatusEmoji = (status) => {
    switch (status) {
      case 'ok': return '✅';
      case 'degraded': return '⚠️';
      case 'no_database': return '❌';
      default: return '❓';
    }
  };

  if (loading) {
    return (
      <div style={styles.container}>
        <div style={styles.card}>
          <h1 style={styles.title}>System Health Check</h1>
          <p style={styles.loading}>Loading...</p>
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div style={styles.container}>
        <div style={styles.card}>
          <h1 style={styles.title}>System Health Check</h1>
          <div style={{...styles.statusBadge, backgroundColor: '#ef4444'}}>
            ❌ Error
          </div>
          <p style={styles.errorText}>Failed to connect to API: {error}</p>
          <button onClick={fetchHealth} style={styles.button}>Retry</button>
        </div>
      </div>
    );
  }

  return (
    <div style={styles.container}>
      <div style={styles.card}>
        <h1 style={styles.title}>🏥 System Health Check</h1>
        
        {/* Overall Status */}
        <div style={{...styles.statusBadge, backgroundColor: getStatusColor(healthData.status)}}>
          {getStatusEmoji(healthData.status)} Status: {healthData.status.toUpperCase()}
        </div>

        {/* Database Status */}
        <div style={styles.section}>
          <h2 style={styles.sectionTitle}>💾 Database</h2>
          <div style={styles.infoGrid}>
            <div style={styles.infoItem}>
              <span style={styles.label}>Connected:</span>
              <span style={styles.value}>
                {healthData.database.connected ? '✅ Yes' : '❌ No'}
              </span>
            </div>
            {healthData.database.database_name && (
              <div style={styles.infoItem}>
                <span style={styles.label}>Database:</span>
                <span style={styles.value}>{healthData.database.database_name}</span>
              </div>
            )}
            {healthData.database.version && (
              <div style={styles.infoItem}>
                <span style={styles.label}>PostgreSQL Version:</span>
                <span style={styles.value}>{healthData.database.version}</span>
              </div>
            )}
            {healthData.database.error && (
              <div style={styles.errorBox}>
                ⚠️ {healthData.database.error}
              </div>
            )}
          </div>
        </div>

        {/* Extensions Status */}
        <div style={styles.section}>
          <h2 style={styles.sectionTitle}>🔌 Extensions</h2>
          
          {/* pgvector */}
          <div style={styles.extensionCard}>
            <h3 style={styles.extensionTitle}>
              {healthData.extensions.pgvector.available ? '✅' : '❌'} pgvector
            </h3>
            <div style={styles.infoGrid}>
              <div style={styles.infoItem}>
                <span style={styles.label}>Status:</span>
                <span style={styles.value}>
                  {healthData.extensions.pgvector.available ? 'Available' : 'Not Available'}
                </span>
              </div>
              {healthData.extensions.pgvector.version && (
                <div style={styles.infoItem}>
                  <span style={styles.label}>Version:</span>
                  <span style={styles.value}>{healthData.extensions.pgvector.version}</span>
                </div>
              )}
              {healthData.extensions.pgvector.error && (
                <div style={styles.errorBox}>
                  ⚠️ {healthData.extensions.pgvector.error}
                </div>
              )}
            </div>
          </div>

          {/* AGE */}
          <div style={styles.extensionCard}>
            <h3 style={styles.extensionTitle}>
              {healthData.extensions.age.available ? '✅' : '❌'} Apache AGE
            </h3>
            <div style={styles.infoGrid}>
              <div style={styles.infoItem}>
                <span style={styles.label}>Status:</span>
                <span style={styles.value}>
                  {healthData.extensions.age.available ? 'Available' : 'Not Available'}
                </span>
              </div>
              {healthData.extensions.age.version && (
                <div style={styles.infoItem}>
                  <span style={styles.label}>Version:</span>
                  <span style={styles.value}>{healthData.extensions.age.version}</span>
                </div>
              )}
              {healthData.extensions.age.error && (
                <div style={styles.errorBox}>
                  ⚠️ {healthData.extensions.age.error}
                </div>
              )}
            </div>
          </div>
        </div>

        {/* Refresh Button */}
        <button onClick={fetchHealth} style={styles.button}>
          🔄 Refresh
        </button>

        {/* Timestamp */}
        <p style={styles.timestamp}>
          Last checked: {new Date().toLocaleString()}
        </p>
      </div>
    </div>
  );
}

const styles = {
  container: {
    minHeight: '100vh',
    background: 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)',
    padding: '2rem',
    fontFamily: '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif',
  },
  card: {
    maxWidth: '800px',
    margin: '0 auto',
    backgroundColor: 'white',
    borderRadius: '16px',
    padding: '2rem',
    boxShadow: '0 20px 60px rgba(0,0,0,0.3)',
  },
  title: {
    fontSize: '2rem',
    fontWeight: 'bold',
    marginBottom: '1.5rem',
    color: '#1f2937',
    textAlign: 'center',
  },
  loading: {
    textAlign: 'center',
    fontSize: '1.2rem',
    color: '#6b7280',
  },
  statusBadge: {
    display: 'inline-block',
    padding: '0.75rem 1.5rem',
    borderRadius: '8px',
    color: 'white',
    fontWeight: 'bold',
    fontSize: '1.1rem',
    marginBottom: '2rem',
  },
  section: {
    marginBottom: '2rem',
    padding: '1.5rem',
    backgroundColor: '#f9fafb',
    borderRadius: '12px',
    border: '1px solid #e5e7eb',
  },
  sectionTitle: {
    fontSize: '1.5rem',
    fontWeight: 'bold',
    marginBottom: '1rem',
    color: '#1f2937',
  },
  extensionCard: {
    marginBottom: '1rem',
    padding: '1rem',
    backgroundColor: 'white',
    borderRadius: '8px',
    border: '1px solid #e5e7eb',
  },
  extensionTitle: {
    fontSize: '1.2rem',
    fontWeight: 'bold',
    marginBottom: '0.75rem',
    color: '#374151',
  },
  infoGrid: {
    display: 'grid',
    gap: '0.75rem',
  },
  infoItem: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
    padding: '0.5rem',
    backgroundColor: '#f3f4f6',
    borderRadius: '6px',
  },
  label: {
    fontWeight: '600',
    color: '#4b5563',
  },
  value: {
    color: '#1f2937',
    fontFamily: 'monospace',
  },
  errorBox: {
    padding: '0.75rem',
    backgroundColor: '#fef2f2',
    border: '1px solid #fecaca',
    borderRadius: '6px',
    color: '#991b1b',
    fontSize: '0.9rem',
  },
  errorText: {
    color: '#ef4444',
    marginBottom: '1rem',
    padding: '1rem',
    backgroundColor: '#fef2f2',
    borderRadius: '8px',
    border: '1px solid #fecaca',
  },
  button: {
    width: '100%',
    padding: '0.75rem',
    backgroundColor: '#667eea',
    color: 'white',
    border: 'none',
    borderRadius: '8px',
    fontSize: '1rem',
    fontWeight: 'bold',
    cursor: 'pointer',
    transition: 'background-color 0.2s',
    marginTop: '1rem',
  },
  timestamp: {
    textAlign: 'center',
    color: '#6b7280',
    fontSize: '0.875rem',
    marginTop: '1rem',
  },
};

