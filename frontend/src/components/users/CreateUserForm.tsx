import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { UserService } from '../../api/UserService';
import { RoleService } from '../../api/RoleService';
import { OrganizationService } from '../../api/OrganizationService';
import { useAuth, usePermissions } from '../../AuthContext';
import { Permission } from '../../types/permissions';
import type { CreateUserRequest } from '../../types/auth';
import type { RoleResponse } from '../../types/roles';
import type { OrganizationResponse } from '../../types/organizations';
import ErrorDisplay from '../common/ErrorDisplay';
import { ApiErrorWithDetails } from '../../errors/ApiErrorWithDetails';
import { useOrganization } from '../../OrganizationContext';

const CreateUserForm: React.FC = () => {
  const navigate = useNavigate();
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [email, setEmail] = useState('');
  const [displayName, setDisplayName] = useState('');
  const [selectedRoles, setSelectedRoles] = useState<string[]>([]);
  const [availableRoles, setAvailableRoles] = useState<RoleResponse[]>([]);
  const [availableOrganizations, setAvailableOrganizations] = useState<OrganizationResponse[]>([]);
  const [selectedOrganizationId, setSelectedOrganizationId] = useState<string>('');
  const [error, setError] = useState<{ message: string; details?: string } | null>(null);

  const { userContext } = useAuth();
  const { hasPermission } = usePermissions();
  const { selectedOrganization } = useOrganization();
  const canManageGlobalUsers = hasPermission(Permission.MANAGE_USERS_GLOBAL);

  useEffect(() => {
    const fetchRolesAndOrganizations = async () => {
      try {
        const rolesData = await RoleService.getAllRoles();
        setAvailableRoles(rolesData);

        if (!selectedOrganization && canManageGlobalUsers) {
          const response = await OrganizationService.getAllOrganizations(1000);
          setAvailableOrganizations(response.items);
          if (response.items.length > 0) {
            setSelectedOrganizationId(response.items[0].organizationId.toString());
          }
        } else if (selectedOrganization) {
          setSelectedOrganizationId(selectedOrganization.organizationId.toString());
        } else if (userContext?.user?.organization?.organizationId) {
          setSelectedOrganizationId(userContext.user.organization.organizationId.toString());
        }
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
    fetchRolesAndOrganizations();
  }, [canManageGlobalUsers, selectedOrganization, userContext]);

  const handleRoleChange = (e: React.ChangeEvent<HTMLSelectElement>) => {
    const options = Array.from(e.target.options);
    const values = options.filter(option => option.selected).map(option => option.value);
    setSelectedRoles(values);
  };

  const handleSubmit = async (event: React.FormEvent) => {
    event.preventDefault();
    setError(null);

    try {
      let organizationIdToUse;
      if (selectedOrganization) {
        organizationIdToUse = selectedOrganization.organizationId;
      } else if (canManageGlobalUsers) {
        organizationIdToUse = selectedOrganizationId ? parseInt(selectedOrganizationId) : undefined;
      } else {
        organizationIdToUse = userContext?.user?.organization?.organizationId;
      }

      if (organizationIdToUse === undefined) {
        setError({ message: 'Organization must be selected.' });
        return;
      }

      const request: CreateUserRequest = {
        username,
        password,
        email,
        displayName,
        roles: selectedRoles,
        organizationId: organizationIdToUse,
      };

      await UserService.createUser(request);
      navigate('/users'); // Redirect to user list after creation
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
    <div className="card">
      <div className="card-body">
        <h2 className="card-title">Create New User</h2>
        <ErrorDisplay error={error} />
        <form onSubmit={handleSubmit}>
          <div className="mb-3">
            <label htmlFor="username" className="form-label">Username:</label>
            <input type="text" id="username" className="form-control" value={username} onChange={(e) => setUsername(e.target.value)} required />
          </div>
          <div className="mb-3">
            <label htmlFor="password" className="form-label">Password:</label>
            <input type="password" id="password" className="form-control" value={password} onChange={(e) => setPassword(e.target.value)} required />
          </div>
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
          {!selectedOrganization && canManageGlobalUsers && (
            <div className="mb-3">
              <label htmlFor="organization" className="form-label">Organization:</label>
              <select
                id="organization"
                className="form-select"
                value={selectedOrganizationId}
                onChange={(e) => setSelectedOrganizationId(e.target.value)}
                required
              >
                <option value="">Select an Organization</option>
                {availableOrganizations.map(org => (
                  <option key={org.organizationId} value={org.organizationId}>
                    {org.name}
                  </option>
                ))}
              </select>
            </div>
          )}
          <button type="submit" className="btn btn-primary">Create User</button>
          <button type="button" className="btn btn-secondary ms-2" onClick={() => navigate('/users')}>Cancel</button>
        </form>
      </div>
    </div>
  );
};

export default CreateUserForm;
