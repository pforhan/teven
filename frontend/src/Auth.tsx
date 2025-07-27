import React, { useState } from 'react';

interface AuthProps {
  onLogin: (token: string, userId: number, username: string, displayName: string, role: string) => void;
}

const Auth: React.FC<AuthProps> = ({ onLogin }) => {
  const [isRegistering, setIsRegistering] = useState(false);
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [email, setEmail] = useState('');
  const [displayName, setDisplayName] = useState('');
  const [role, setRole] = useState('staff'); // Default role
  const [error, setError] = useState<string | null>(null);

  const handleSubmit = async (event: React.FormEvent) => {
    event.preventDefault();
    setError(null);

    const url = isRegistering ? '/api/users/register' : '/api/users/login';
    const body = isRegistering
      ? JSON.stringify({ username, password, email, displayName, role })
      : JSON.stringify({ username, password });

    try {
      const response = await fetch(url, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body,
      });

      if (!response.ok) {
        const errorData = await response.json();
        throw new Error(errorData.message || 'Authentication failed');
      }

      const data = await response.json();
      onLogin(data.token, data.userId, data.username, data.displayName, data.role);
    } catch (err: any) {
      setError(err.message);
    }
  };

  return (
    <div className="auth-container">
      <h2>{isRegistering ? 'Register' : 'Login'}</h2>
      {error && <p className="error-message">{error}</p>}
      <form onSubmit={handleSubmit}>
        <div>
          <label htmlFor="username">Username:</label>
          <input
            type="text"
            id="username"
            value={username}
            onChange={(e) => setUsername(e.target.value)}
            required
          />
        </div>
        <div>
          <label htmlFor="password">Password:</label>
          <input
            type="password"
            id="password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            required
          />
        </div>
        {isRegistering && (
          <>
            <div>
              <label htmlFor="email">Email:</label>
              <input
                type="email"
                id="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                required
              />
            </div>
            <div>
              <label htmlFor="displayName">Display Name:</label>
              <input
                type="text"
                id="displayName"
                value={displayName}
                onChange={(e) => setDisplayName(e.target.value)}
                required
              />
            </div>
            <div>
              <label htmlFor="role">Role:</label>
              <select id="role" value={role} onChange={(e) => setRole(e.target.value)}>
                <option value="staff">Staff</option>
                <option value="organizer">Organizer</option>
              </select>
            </div>
          </>
        )}
        <button type="submit">{isRegistering ? 'Register' : 'Login'}</button>
      </form>
      <button onClick={() => setIsRegistering(!isRegistering)}>
        {isRegistering ? 'Already have an account? Login' : 'Need an account? Register'}
      </button>
    </div>
  );
};

export default Auth;
