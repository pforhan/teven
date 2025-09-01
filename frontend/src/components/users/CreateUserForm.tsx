import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { UserService } from '../../api/UserService';
import { RoleService } from '../../api/RoleService';
import { OrganizationService } from '../../api/OrganizationService';
import { useAuth } from '../../AuthContext';
import type { CreateUserRequest } from '../../types/auth';
import type { RoleResponse } from '../../types/roles';
import type { OrganizationResponse } from '../../types/organizations';
import ErrorDisplay from '../common/ErrorDisplay';
import { Constants } from '../../core/Constants';

const CreateUserForm: React.FC = () => {
  const navigate = useNavigate();
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [email, setEmail] = useState('');
  const [displayName, setDisplayName] = useState('');
  const [selectedRoles, setSelectedRoles] = useState<string[]>([]);
  const [availableRoles, setAvailableRoles] = useState<RoleResponse[]>([]);
  const [availableOrganizations, setAvailableOrganizations] = useState<OrganizationResponse[]>([]);
  const [selectedOrganization, setSelectedOrganization] = useState<string>('');
  const [error, setError] = useState<string | null>(null);

  const { userContext } = useAuth();

  const isSuperAdmin = userContext?.user?.roles?.includes(Constants.ROLE_SUPERADMIN) || false;

  useEffect(() => {
    const fetchRolesAndOrganizations = async () => {
      try {
        const rolesData = await RoleService.getAllRoles();
        setAvailableRoles(rolesData);

        if (isSuperAdmin) {
          const orgsData = await OrganizationService.getAllOrganizations();
          setAvailableOrganizations(orgsData);
        }
      } catch (err) {
        if (err instanceof Error) {
          setError(err.message);
        } else {
          setError('An unknown error occurred');
        }
      }
    };
    fetchRolesAndOrganizations();
  }, [isSuperAdmin]);

  const handleRoleChange = (e: React.ChangeEvent<HTMLSelectElement>) => {
    const options = Array.from(e.target.options);
    const values = options.filter(option => option.selected).map(option => option.value);
    setSelectedRoles(values);
  };

  const handleSubmit = async (event: React.FormEvent) => {
    event.preventDefault();
    setError(null);

    try {
      const request: CreateUserRequest = {
        username,
        password,
        email,
        displayName,
        roles: selectedRoles,
        organizationId: isSuperAdmin ? (selectedOrganization || undefined) : userContext?.organization?.organizationId?.toString(),
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
          <label htmlFor="roles">Roles:</label>
          <select id="roles" multiple={true} value={selectedRoles} onChange={handleRoleChange}>
            {availableRoles.map(role => (
              <option key={role.roleId} value={role.roleName}>
                {role.roleName}
              </option>
            ))}
          </select>
        </div>
        {isSuperAdmin && (
          <div>
            <label htmlFor="organization">Organization:</label>
            <select
              id="organization"
              value={selectedOrganization}
              onChange={(e) => setSelectedOrganization(e.target.value)}
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
        <button type="submit">Create User</button>
        <button type="button" onClick={() => navigate('/users')}>Cancel</button>
      </form>
    </div>
  );
};

export default CreateUserForm;
