import React, { useState, useEffect, useCallback } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import { FaEdit, FaTrash } from 'react-icons/fa';
import { OverlayTrigger, Tooltip } from 'react-bootstrap';
import { UserService } from '../../api/UserService';
import { InvitationService } from '../../api/InvitationService';
import type { UserResponse } from '../../types/auth';
import { usePermissions } from '../../AuthContext';
import { Permission } from '../../types/permissions';
import TableView, { type Column } from '../common/TableView';
import { ApiErrorWithDetails } from '../../errors/ApiErrorWithDetails';
import { CreateInvitationForm } from './CreateInvitationForm';
import type { InvitationResponse } from '../../types/api';

const UserList: React.FC = () => {
  const navigate = useNavigate();
  const [users, setUsers] = useState<UserResponse[]>([]);
  const [invitations, setInvitations] = useState<InvitationResponse[]>([]);
  const [error, setError] = useState<{ message: string; details?: string } | null>(null);
  const [showCreateInvitationForm, setShowCreateInvitationForm] = useState<boolean>(false);
  const { hasPermission } = usePermissions();
  const canViewUsers = hasPermission(Permission.VIEW_USERS_ORGANIZATION) || hasPermission(Permission.VIEW_USERS_GLOBAL);
  const canManageUsers = hasPermission(Permission.MANAGE_USERS_GLOBAL) || hasPermission(Permission.MANAGE_USERS_ORGANIZATION);
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

  const fetchInvitations = useCallback(async () => {
    if (!canManageUsers) return;
    try {
      const fetchedInvitations = await InvitationService.getUnusedInvitations();
      setInvitations(fetchedInvitations);
    } catch (err: unknown) {
      if (err instanceof ApiErrorWithDetails) {
        setError({ message: err.message, details: err.details });
      } else if (err instanceof Error) {
        setError({ message: err.message });
      } else {
        setError({ message: 'An unknown error occurred' });
      }
    }
  }, [canManageUsers]);

  useEffect(() => {
    if (canViewUsers) {
      fetchUsers();
    }
    if (canManageUsers) {
      fetchInvitations();
    }
  }, [fetchUsers, fetchInvitations, canViewUsers, canManageUsers]);

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

  const handleDeleteInvitation = async (invitationId: number) => {
    if (window.confirm('Are you sure you want to delete this invitation?')) {
      try {
        await InvitationService.deleteInvitation(invitationId);
        fetchInvitations(); // Re-fetch invitations after deletion
      } catch (err) {
        if (err instanceof ApiErrorWithDetails) {
          setError({ message: err.message, details: err.details });
        } else if (err instanceof Error) {
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

  if (hasPermission(Permission.VIEW_USERS_GLOBAL)) {
    columns.push({ key: 'organization', label: 'Organization', render: (user: UserResponse) => user.organization?.name || 'N/A' });
  }

  const [copiedInvitationId, setCopiedInvitationId] = useState<number | null>(null);

  const handleCopyInvitationLink = (invitation: InvitationResponse) => {
    const invitationUrl = `${window.location.origin}/register?token=${invitation.token}`;
    navigator.clipboard.writeText(invitationUrl).then(() => {
      setCopiedInvitationId(invitation.invitationId);
      setTimeout(() => setCopiedInvitationId(null), 2000); // Reset after 2 seconds
    }).catch(err => {
      console.error('Failed to copy invitation link:', err);
    });
  };

  const invitationColumns: Column<InvitationResponse>[] = [
    { key: 'roleName', label: 'Role' },
    { key: 'note', label: 'Note', render: (invitation: InvitationResponse) => invitation.note || 'N/A' },
    { key: 'invitationUrl', label: 'Link', render: (invitation: InvitationResponse) => (
      <div className="d-flex align-items-center">
        <button
          className="btn btn-sm btn-outline-secondary me-2"
          onClick={() => handleCopyInvitationLink(invitation)}
        >
          {copiedInvitationId === invitation.invitationId ? 'Copied!' : 'Copy Link'}
        </button>
        <span className="text-muted text-truncate" style={{ maxWidth: '150px' }}>
          {`${window.location.origin}/register?token=${invitation.token}`}
        </span>
      </div>
    ) },
    { key: 'expiresAt', label: 'Expires', render: (invitation: InvitationResponse) => new Date(invitation.expiresAt).toLocaleDateString() },
    { key: 'actions', label: 'Actions', render: (invitation: InvitationResponse) => (
      <button
        className="btn btn-sm btn-danger"
        onClick={() => handleDeleteInvitation(invitation.invitationId)}
      >
        Delete
      </button>
    ) },
  ];

  return (
    <div className="container-fluid">
      <div className="d-flex justify-content-between align-items-center mb-3">
        <h2>User Management</h2>
        <div className="d-flex">
          {canManageUsers && (
            <button className="btn btn-primary me-2" onClick={() => navigate('/users/create')}>Create User</button>
          )}
          {canManageUsers && (
            <button className="btn btn-info" onClick={() => setShowCreateInvitationForm(true)}>Create Invitation</button>
          )}
        </div>
      </div>

      {showCreateInvitationForm && (
        <div className="mb-4">
          <CreateInvitationForm
            onInvitationCreated={() => {
              setShowCreateInvitationForm(false);
              fetchInvitations(); // Refresh invitations list
            }}
            onCancel={() => setShowCreateInvitationForm(false)}
          />
        </div>
      )}

      {canManageUsers && invitations.length > 0 && (
        <div className="mt-5">
          <h2 className="text-2xl font-bold mb-4">Unused Invitations</h2>
          <TableView
            data={invitations}
            columns={invitationColumns}
            keyField="invitationId"
            error={error}
          />
        </div>
      )}

      <h2>Users</h2>
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