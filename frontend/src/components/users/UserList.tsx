import React, { useState, useEffect, useCallback } from 'react';
import { useNavigate } from 'react-router-dom';
import { UserService } from '../../api/UserService';
import type { UserResponse } from '../../types/auth';
import { usePermissions } from '../../AuthContext';
import ErrorDisplay from '../common/ErrorDisplay';

const UserList: React.FC = () => {
  const navigate = useNavigate();
  const [users, setUsers] = useState<UserResponse[]>([]);
  const [error, setError] = useState<string | null>(null);
  const { hasPermission } = usePermissions();
  const canViewUsers = hasPermission('VIEW_USERS_ORGANIZATION') || hasPermission('VIEW_USERS_GLOBAL');

  const fetchUsers = useCallback(async () => {
    try {
      const userData = await UserService.getAllUsers();
      setUsers(userData);
    } catch (err) {
      if (err instanceof Error) {
        setError(err.message);
      } else {
        setError('An unknown error occurred');
      }
    }
  }, []);

  useEffect(() => {
    if (canViewUsers) {
      fetchUsers();
    }
  }, [fetchUsers, canViewUsers]);

  if (!canViewUsers) {
    return <ErrorDisplay message="Access denied: You do not have permission to view users." />;
  }

  return (
    <div>
      <h2>Users</h2>
      <ErrorDisplay message={error} />

      {hasPermission('MANAGE_USERS_GLOBAL') && (
        <button onClick={() => navigate('/users/create')}>Create User</button>
      )}
      <table>
        <thead>
          <tr>
            <th>Username</th>
            <th>Display Name</th>
            <th>Email</th>
            <th>Roles</th>
            {hasPermission('VIEW_USERS_GLOBAL') && <th>Organization</th>}
            <th>Actions</th>
          </tr>
        </thead>
        <tbody>
          {users.map(user => (
            <tr key={user.userId}>
              <td>{user.username}</td>
              <td>{user.displayName}</td>
              <td>{user.email}</td>
              <td>{user.roles.join(', ')}</td>
              {hasPermission('VIEW_USERS_GLOBAL') && <td>{user.organization?.name || 'N/A'}</td>}
              <td>
                {hasPermission('MANAGE_USERS_GLOBAL') && (
                  <button onClick={() => navigate(`/users/edit/${user.userId}`)}>Edit</button>
                )}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
};

export default UserList;
