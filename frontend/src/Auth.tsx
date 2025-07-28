import React, { useState } from 'react';
import type { LoginRequest, RegisterRequest, LoginResponse, UserResponse } from './types/auth';
import { AuthService } from './api/AuthService';

interface AuthProps {
  onLogin: (response: LoginResponse) => void;
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

    try {
      if (isRegistering) {
        const registerRequest: RegisterRequest = {
          username,
          password,
          email,
          displayName,
          role,
        };
        const data: UserResponse = await AuthService.register(registerRequest);
        // For registration, we don't get a token directly, so we might need to log in after registering
        // For now, we'll just assume success and let the user log in manually or handle it differently.
        // This part might need adjustment based on desired UX after registration.
        console.log('Registration successful:', data);
        setIsRegistering(false); // Switch to login form after successful registration
      } else {
        const loginRequest: LoginRequest = {
          username,
          password,
        };
        const data: LoginResponse = await AuthService.login(loginRequest);
        onLogin(data);
      }
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
