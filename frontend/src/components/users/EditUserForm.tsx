import React, { useState, useEffect } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { UserService } from '../../api/UserService';
import type { UserResponse, UpdateUserRequest } from '../../types/auth';
import ErrorDisplay from '../common/ErrorDisplay';

const EditUserForm: React.FC = () => {
  const navigate = useNavigate();
  const { userId } = useParams<{ userId: string }>();
  const [user, setUser] = useState<UserResponse | null>(null);
  const [email, setEmail] = useState('');
  const [displayName, setDisplayName] = useState('');
  const [roles, setRoles] = useState<string[]>([]);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const fetchUser = async () => {
      if (!userId) return;
      try {
        const fetchedUser = await UserService.getUser(parseInt(userId));
        setUser(fetchedUser);
        setEmail(fetchedUser.email);
        setDisplayName(fetchedUser.displayName);
        setRoles(fetchedUser.roles);
      } catch (err) {
        if (err instanceof Error) {
          setError(err.message);
        } else {
          setError('An unknown error occurred');
        }
      }
    };
    fetchUser();
  }, [userId]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);

    if (!userId) return;

    try {
      const request: UpdateUserRequest = {
        email,
        displayName,
        roles,
      };

      await UserService.updateUser(parseInt(userId), request);
      navigate('/users');
    } catch (err) {
      if (err instanceof Error) {
        setError(err.message);
      } else {
        setError('An unknown error occurred');
      }
    }
  };

  if (!user) {
    return <div>Loading user...</div>;
  }

  return (
    <div>
      <h2>Edit User: {user.displayName}</h2>
      <ErrorDisplay message={error} />
      <form onSubmit={handleSubmit}>
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
        <button type="submit">Update User</button>
        <button type="button" onClick={() => navigate('/users')}>Cancel</button>
      </form>
    </div>
  );
};

export default EditUserForm;
