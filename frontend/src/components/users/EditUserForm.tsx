import React, { useState, useEffect } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { UserService } from '../../api/UserService';
import { RoleService } from '../../api/RoleService';
import type { UserResponse, UpdateUserRequest } from '../../types/auth';
import type { RoleResponse } from '../../types/roles';
import ErrorDisplay from '../common/ErrorDisplay';

const EditUserForm: React.FC = () => {
  const navigate = useNavigate();
  const { userId } = useParams<{ userId: string }>();
  const [user, setUser] = useState<UserResponse | null>(null);
  const [email, setEmail] = useState('');
  const [displayName, setDisplayName] = useState('');
  const [selectedRoles, setSelectedRoles] = useState<string[]>([]);
  const [availableRoles, setAvailableRoles] = useState<RoleResponse[]>([]);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const fetchUserAndRoles = async () => {
      if (!userId) return;
      try {
        const fetchedUser = await UserService.getUser(parseInt(userId));
        setUser(fetchedUser);
        setEmail(fetchedUser.email);
        setDisplayName(fetchedUser.displayName);
        setSelectedRoles(fetchedUser.roles);

        const rolesData = await RoleService.getAllRoles();
        setAvailableRoles(rolesData);
      } catch (err) {
        if (err instanceof Error) {
          setError(err.message);
        } else {
          setError('An unknown error occurred');
        }
      }
    };
    fetchUserAndRoles();
  }, [userId]);

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
      const request: UpdateUserRequest = {
        email,
        displayName,
        roles: selectedRoles,
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
          <label htmlFor="roles">Roles:</label>
          <select id="roles" multiple={true} value={selectedRoles} onChange={handleRoleChange}>
            {availableRoles.map(role => (
              <option key={role.roleId} value={role.roleName}>
                {role.roleName}
              </option>
            ))}
          </select>
        </div>
        <button type="submit">Update User</button>
        <button type="button" onClick={() => navigate('/users')}>Cancel</button>
      </form>
    </div>
  );
};

export default EditUserForm;
