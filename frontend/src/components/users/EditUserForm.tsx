import React, { useState, useEffect } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { UserService } from '../../api/UserService';
import { RoleService } from '../../api/RoleService';
import { OrganizationService } from '../../api/OrganizationService';
import type { UserResponse, UpdateUserRequest } from '../../types/auth';
import type { RoleResponse } from '../../types/roles';
import type { OrganizationResponse } from '../../types/organizations';
import ErrorDisplay from '../common/ErrorDisplay';
import { ApiErrorWithDetails } from '../../errors/ApiErrorWithDetails';
import { useAuth, usePermissions } from '../../AuthContext';
import { Permission } from '../../types/permissions';

const EditUserForm: React.FC = () => {
  const navigate = useNavigate();
  const { userId } = useParams<{ userId: string }>();
  const [user, setUser] = useState<UserResponse | null>(null);
  const [email, setEmail] = useState('');
  const [displayName, setDisplayName] = useState('');
  const [selectedRoles, setSelectedRoles] = useState<string[]>([]);
  const [availableRoles, setAvailableRoles] = useState<RoleResponse[]>([]);
  const [availableOrganizations, setAvailableOrganizations] = useState<OrganizationResponse[]>([]);
  const [selectedOrganizationId, setSelectedOrganizationId] = useState<string>('');
  const [error, setError] = useState<{ message: string; details?: string } | null>(null);

  const { } = useAuth();
  const { hasPermission } = usePermissions();
  const canManageGlobalUsers = hasPermission(Permission.MANAGE_USERS_GLOBAL);

  useEffect(() => {
    const fetchUserAndRolesAndOrganizations = async () => {
      if (!userId) return;
      try {
        const fetchedUser = await UserService.getUser(parseInt(userId));
        setUser(fetchedUser);
        setEmail(fetchedUser.email);
        setDisplayName(fetchedUser.displayName);
        setSelectedRoles(fetchedUser.roles);

        const rolesData = await RoleService.getAllRoles();
        setAvailableRoles(rolesData);

        if (canManageGlobalUsers) {
          const orgs = await OrganizationService.getAllOrganizations();
          setAvailableOrganizations(orgs);
        }
        setSelectedOrganizationId(fetchedUser.organization?.organizationId?.toString() || '');
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
    fetchUserAndRolesAndOrganizations();
  }, [userId, canManageGlobalUsers]);

  const handleRoleChange = (e: React.ChangeEvent<HTMLSelectElement>) => {
    const options = Array.from(e.target.options);
    const values = options.filter(option => option.selected).map(option => option.value);
    setSelectedRoles(values);
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);

    if (!userId) return;

    try {
      const organizationIdToUse = canManageGlobalUsers
        ? (selectedOrganizationId ? parseInt(selectedOrganizationId) : undefined)
        : undefined; // Organization ID is not sent if not global manager

      const request: UpdateUserRequest = {
        email,
        displayName,
        roles: selectedRoles,
        organizationId: organizationIdToUse,
      };

      await UserService.updateUser(parseInt(userId), request);
      navigate('/users');
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

  if (!user) {
    return <div>Loading user...</div>;
  }

  return (
    <div className="card">
      <div className="card-body">
        <h2 className="card-title">Edit User: {user.displayName}</h2>
        <ErrorDisplay error={error} />
        <form onSubmit={handleSubmit}>
          <div className="mb-3">
            <label htmlFor="email" className="form-label">Email:</label>
            <input type="email" id="email" className="form-control" value={email} onChange={(e) => setEmail(e.target.value)} required />
          </div>
          <div className="mb-3">
            <label htmlFor="displayName" className="form-label">Display Name:</label>
            <input type="text" id="displayName" className="form-control" value={displayName} onChange={(e) => setDisplayName(e.target.value)} required />
          </div>
          <div className="mb-3">
            <label htmlFor="roles" className="form-label">Roles:</label>
            <select id="roles" multiple={true} className="form-select" value={selectedRoles} onChange={handleRoleChange}>
              {availableRoles.map(role => (
                <option key={role.roleId} value={role.roleName}>
                  {role.roleName}
                </option>
              ))}
            </select>
          </div>

          {canManageGlobalUsers && (
            <div className="mb-3">
              <label htmlFor="organization" className="form-label">Organization:</label>
              <select
                id="organization"
                className="form-select"
                value={selectedOrganizationId}
                onChange={(e) => setSelectedOrganizationId(e.target.value)}
              >
                {availableOrganizations.map(org => (
                  <option key={org.organizationId} value={org.organizationId}>
                    {org.name}
                  </option>
                ))}
              </select>
            </div>
          )}

          <button type="submit" className="btn btn-primary">Update User</button>
          <button type="button" className="btn btn-secondary ms-2" onClick={() => navigate('/users')}>Cancel</button>
        </form>
      </div>
    </div>
  );
};

export default EditUserForm;
