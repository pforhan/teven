import React, { useState } from 'react';
import type { LoginRequest } from './types/auth';
import { AuthService } from './api/AuthService';
import { ApiErrorWithDetails } from './errors/ApiErrorWithDetails';
import ErrorDisplay from './components/common/ErrorDisplay';
import { useAuth } from './AuthContext';

const Auth: React.FC = () => {
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState<{ message: string; details?: string } | null>(null);
  const { refetchUserContext } = useAuth();

  const handleSubmit = async (event: React.FormEvent) => {
    event.preventDefault();
    setError(null);

    try {
      const loginRequest: LoginRequest = {
        username,
        password,
      };
      await AuthService.login(loginRequest);
      await refetchUserContext();
    } catch (err: unknown) {
      if (err instanceof ApiErrorWithDetails) {
        setError({ message: err.message, details: err.details });
      } else if (err instanceof Error) {
        setError({ message: err.message });
      } else {
        setError({ message: 'An unknown error occurred' });
      }
    }
  };

  return (
    <div className="container d-flex justify-content-center align-items-center vh-100">
      <div className="card p-4" style={{ width: '25rem' }}>
        <h2 className="card-title text-center mb-4">Login</h2>
        <ErrorDisplay error={error} />
        <form onSubmit={handleSubmit}>
          <div className="mb-3">
            <label htmlFor="username" className="form-label">Username:</label>
            <input
              type="text"
              id="username"
              className="form-control"
              value={username}
              onChange={(e) => setUsername(e.target.value)}
              required
            />
          </div>
          <div className="mb-3">
            <label htmlFor="password" className="form-label">Password:</label>
            <input
              type="password"
              id="password"
              className="form-control"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              required
            />
          </div>
          <button type="submit" className="btn btn-primary w-100">Login</button>
        </form>
      </div>
    </div>
  );
};

export default Auth;
