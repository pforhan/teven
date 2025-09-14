import React, { useState, useEffect, useCallback } from 'react';
import { useNavigate } from 'react-router-dom';
import { UserService } from '../../api/UserService';
import type { UserResponse } from '../../types/auth';
import { usePermissions } from '../../AuthContext';
import TableView, { type Column } from '../common/TableView';
import { ApiErrorWithDetails } from '../../errors/ApiErrorWithDetails';

const UserList: React.FC = () => {
  const navigate = useNavigate();
  const [users, setUsers] = useState<UserResponse[]>([]);
  const [error, setError] = useState<{ message: string; details?: string } | null>(null);
  const { hasPermission } = usePermissions();
  const canViewUsers = hasPermission('VIEW_USERS_ORGANIZATION') || hasPermission('VIEW_USERS_GLOBAL');
  const canManageUsers = hasPermission('MANAGE_USERS_GLOBAL') || hasPermission('MANAGE_USERS_ORGANIZATION');

  const fetchUsers = useCallback(async () => {
    try {
      const userData = await UserService.getAllUsers();
      setUsers(userData);
    } catch (err: unknown) {
      if (err instanceof ApiErrorWithDetails) {
        setError({ message: err.message, details: err.details });
      } else if (err instanceof Error) {
        setError({ message: err.message });
      } else {
        setError({ message: 'An unknown error occurred' });
      }
    }
  }, []);

  useEffect(() => {
    if (canViewUsers) {
      fetchUsers();
    }
  }, [fetchUsers, canViewUsers]);

  const columns: Column<UserResponse>[] = [
    { key: 'username', label: 'Username' },
    { key: 'displayName', label: 'Display Name' },
    { key: 'email', label: 'Email' },
    { key: 'roles', label: 'Roles', render: (user: UserResponse) => user.roles.join(', ') },
  ];

  if (hasPermission('VIEW_USERS_GLOBAL')) {
    columns.push({ key: 'organization', label: 'Organization', render: (user: UserResponse) => user.organization?.name || 'N/A' });
  }

  const renderActions = (user: UserResponse) => (
    <>
      {canManageUsers && (
        <button onClick={() => navigate(`/users/edit/${user.userId}`)}>Edit</button>
      )}
    </>
  );

  return (
    <TableView
      title="Users"
      data={users}
      columns={columns}
      getKey={(user) => user.userId}
      renderActions={renderActions}
      createButton={{
        label: 'Create User',
        onClick: () => navigate('/users/create'),
        permission: canManageUsers,
      }}
      error={error}
      canView={canViewUsers}
      viewError={{ message: "Access denied: You do not have permission to view users." }}
    />
  );
};

export default UserList;