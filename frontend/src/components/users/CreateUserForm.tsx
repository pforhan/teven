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
    <div className="card">
      <div className="card-body">
        <h2 className="card-title">Create New User</h2>
        <ErrorDisplay message={error} />
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
          {isSuperAdmin && (
            <div className="mb-3">
              <label htmlFor="organization" className="form-label">Organization:</label>
              <select
                id="organization"
                className="form-select"
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
          <button type="submit" className="btn btn-primary">Create User</button>
          <button type="button" className="btn btn-secondary ms-2" onClick={() => navigate('/users')}>Cancel</button>
        </form>
      </div>
    </div>
  );
};

export default CreateUserForm;
