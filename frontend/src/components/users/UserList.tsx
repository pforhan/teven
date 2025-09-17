import React, { useState, useEffect, useCallback } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import { FaEdit, FaTrash } from 'react-icons/fa';
import { OverlayTrigger, Tooltip } from 'react-bootstrap';
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
  const [hoveredUserId, setHoveredUserId] = useState<number | null>(null);

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

  const handleDelete = async (userId: number) => {
    if (window.confirm('Are you sure you want to delete this user?')) {
      try {
        await UserService.deleteUser(userId);
        fetchUsers(); // Re-fetch users after deletion
      } catch (err) {
        if (err instanceof Error) {
          setError({ message: err.message });
        } else {
          setError({ message: 'An unknown error occurred' });
        }
      }
    }
  };

  const columns: Column<UserResponse>[] = [
    { key: 'username', label: 'Username', render: (user: UserResponse) => (
      <div className="d-flex justify-content-between align-items-center position-relative">
        <Link to={`/users/${user.userId}`}>{user.username}</Link>
        {canManageUsers && hoveredUserId === user.userId && (
          <div className="position-absolute top-0 end-0 z-1">
            <OverlayTrigger placement="top" overlay={<Tooltip id={`tooltip-edit-${user.userId}`}>Edit</Tooltip>}>
              <button className="btn btn-sm btn-light me-2" onClick={() => navigate(`/users/edit/${user.userId}`)}><FaEdit /></button>
            </OverlayTrigger>
            <OverlayTrigger placement="top" overlay={<Tooltip id={`tooltip-delete-${user.userId}`}>Delete</Tooltip>}>
              <button className="btn btn-sm btn-light" onClick={() => handleDelete(user.userId)}><FaTrash /></button>
            </OverlayTrigger>
          </div>
        )}
      </div>
    ) },
    { key: 'displayName', label: 'Display Name' },
    { key: 'email', label: 'Email' },
    { key: 'roles', label: 'Roles', render: (user: UserResponse) => user.roles.join(', ') },
  ];

  if (hasPermission('VIEW_USERS_GLOBAL')) {
    columns.push({ key: 'organization', label: 'Organization', render: (user: UserResponse) => user.organization?.name || 'N/A' });
  }

  return (
    <div className="container-fluid">
      <div className="d-flex justify-content-between align-items-center mb-3">
        <h2>Users</h2>
        {canManageUsers && (
          <button className="btn btn-primary" onClick={() => navigate('/users/create')}>Create User</button>
        )}
      </div>

      <TableView
        data={users}
        columns={columns}
        keyField="userId"
        error={error}
        onRowMouseEnter={(user) => setHoveredUserId(user.userId)}
        onRowMouseLeave={() => setHoveredUserId(null)}
      />
    </div>
  );
};

export default UserList;