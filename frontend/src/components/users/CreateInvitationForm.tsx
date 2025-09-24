import React, { useState, useEffect } from 'react';
import { RoleService } from '../../api/RoleService';
import type { RoleResponse } from '../../types/roles';
import { InvitationService } from '../../api/InvitationService'; // We'll create this next
import { useAuth } from '../../AuthContext';
import { Permission } from '../../types/permissions';

interface CreateInvitationFormProps {
  onInvitationCreated: (invitationLink: string) => void;
  onCancel: () => void;
}

export const CreateInvitationForm: React.FC<CreateInvitationFormProps> = ({ onInvitationCreated, onCancel }) => {
  const [roles, setRoles] = useState<RoleResponse[]>([]);
  const [selectedRoleId, setSelectedRoleId] = useState<number | null>(null);
  const [invitationLink, setInvitationLink] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState<boolean>(false);
  const { userContext } = useAuth();

  useEffect(() => {
    const fetchRoles = async () => {
      try {
        const fetchedRoles = await RoleService.getAllRoles();
        setRoles(fetchedRoles);
        if (fetchedRoles.length > 0) {
          setSelectedRoleId(fetchedRoles[0].roleId);
        }
      } catch (err) {
        setError('Failed to fetch roles.');
        console.error('Failed to fetch roles:', err);
      }
    };
    fetchRoles();
  }, []);

  const handleCreateInvitation = async () => {
    if (!selectedRoleId || !userContext?.user.organization.organizationId) {
      setError('Please select a role and ensure organization ID is available.');
      return;
    }
    setLoading(true);
    setError(null);
    setInvitationLink(null);

    try {
      const response = await InvitationService.createInvitation(userContext.user.organization.organizationId, selectedRoleId);
      setInvitationLink(response.invitationUrl);
      onInvitationCreated(response.invitationUrl);
    } catch (err) {
      setError('Failed to create invitation.');
      console.error('Failed to create invitation:', err);
    } finally {
      setLoading(false);
    }
  };

  if (!userContext?.permissions.includes(Permission.MANAGE_USERS_ORGANIZATION)) {
    return <div className="text-red-500">You do not have permission to create invitations.</div>;
  }

  return (
    <div className="p-4 border rounded shadow-md">
      <h2 className="text-xl font-bold mb-4">Create New Invitation</h2>
      {error && <div className="text-red-500 mb-4">{error}</div>}
      {invitationLink ? (
        <div>
          <p className="mb-2">Invitation Link:</p>
          <input
            type="text"
            value={invitationLink}
            readOnly
            className="w-full p-2 border rounded bg-gray-100 mb-4"
          />
          <button
            className="bg-gray-500 hover:bg-gray-700 text-white font-bold py-2 px-4 rounded"
            onClick={onCancel}
          >
            Close
          </button>
        </div>
      ) : (
        <div>
          <div className="mb-4">
            <label htmlFor="roleSelect" className="block text-sm font-medium text-gray-700">
              Select Role:
            </label>
            <select
              id="roleSelect"
              className="mt-1 block w-full p-2 border border-gray-300 rounded-md shadow-sm"
              value={selectedRoleId || ''}
              onChange={(e) => setSelectedRoleId(Number(e.target.value))}
              disabled={loading}
            >
              {roles.map((role) => (
                <option key={role.roleId} value={role.roleId}>
                  {role.roleName}
                </option>
              ))}
            </select>
          </div>
          <div className="flex justify-end space-x-2">
            <button
              className="bg-gray-500 hover:bg-gray-700 text-white font-bold py-2 px-4 rounded"
              onClick={onCancel}
              disabled={loading}
            >
              Cancel
            </button>
            <button
              className="bg-blue-500 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded"
              onClick={handleCreateInvitation}
              disabled={loading}
            >
              {loading ? 'Creating...' : 'Create Invitation'}
            </button>
          </div>
        </div>
      )}
    </div>
  );
};
