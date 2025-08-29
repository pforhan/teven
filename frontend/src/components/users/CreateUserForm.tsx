import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { UserService } from '../../api/UserService';
import type { CreateUserRequest } from '../../types/auth';
import ErrorDisplay from '../common/ErrorDisplay';

const CreateUserForm: React.FC = () => {
  const navigate = useNavigate();
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [email, setEmail] = useState('');
  const [displayName, setDisplayName] = useState('');
  const [roles, setRoles] = useState<string[]>([]);
  const [error, setError] = useState<string | null>(null);

  const handleSubmit = async (event: React.FormEvent) => {
    event.preventDefault();
    setError(null);

    try {
      const request: CreateUserRequest = {
        username,
        password,
        email,
        displayName,
        roles,
      };

      await UserService.createUser(request);
      navigate('/users'); // Redirect to user list after creation
    } catch (err) {
      if (err instanceof Error) {
        setError(err.message);
      } else {
        setError('An unknown error occurred');
      }
    }
  };

  return (
    <div>
      <h2>Create New User</h2>
      <ErrorDisplay message={error} />
      <form onSubmit={handleSubmit}>
        <div>
          <label htmlFor="username">Username:</label>
          <input type="text" id="username" value={username} onChange={(e) => setUsername(e.target.value)} required />
        </div>
        <div>
          <label htmlFor="password">Password:</label>
          <input type="password" id="password" value={password} onChange={(e) => setPassword(e.target.value)} required />
        </div>
        <div>
          <label htmlFor="email">Email:</label>
          <input type="email" id="email" value={email} onChange={(e) => setEmail(e.target.value)} required />
        </div>
        <div>
          <label htmlFor="displayName">Display Name:</label>
          <input type="text" id="displayName" value={displayName} onChange={(e) => setDisplayName(e.target.value)} required />
        </div>
        <div>
          <label htmlFor="roles">Roles (comma-separated):</label>
          <input type="text" id="roles" value={roles.join(', ')} onChange={(e) => setRoles(e.target.value.split(',').map(role => role.trim()))} />
        </div>
        <button type="submit">Create User</button>
        <button type="button" onClick={() => navigate('/users')}>Cancel</button>
      </form>
    </div>
  );
};

export default CreateUserForm;
