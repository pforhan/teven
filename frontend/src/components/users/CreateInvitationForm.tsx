import React, { useState, useEffect } from 'react';
import { RoleService } from '../../api/RoleService';
import type { RoleResponse } from '../../types/roles';
import { InvitationService } from '../../api/InvitationService';
import { OrganizationService } from '../../api/OrganizationService';
import type { OrganizationResponse } from '../../types/organizations';
import { useAuth } from '../../AuthContext';
import { Permission } from '../../types/permissions';

interface CreateInvitationFormProps {
  onInvitationCreated: (invitationLink: string) => void;
  onCancel: () => void;
}

export const CreateInvitationForm: React.FC<CreateInvitationFormProps> = ({ onInvitationCreated, onCancel }) => {
  const [roles, setRoles] = useState<RoleResponse[]>([]);
  const [organizations, setOrganizations] = useState<OrganizationResponse[]>([]);
  const [selectedRoleId, setSelectedRoleId] = useState<number | null>(null);
  const [selectedOrganizationId, setSelectedOrganizationId] = useState<number | null>(null);
  const [note, setNote] = useState<string>('');
  const [invitationLink, setInvitationLink] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState<boolean>(false);
  const { userContext } = useAuth();

  useEffect(() => {
    const fetchRolesAndOrgs = async () => {
      try {
        const fetchedRoles = await RoleService.getAllRoles();
        setRoles(fetchedRoles);
        if (fetchedRoles.length > 0) {
          setSelectedRoleId(fetchedRoles[0].roleId);
        }

        if (userContext?.permissions.includes(Permission.MANAGE_INVITATIONS_GLOBAL)) {
          const response = await OrganizationService.getAllOrganizations(1000);
          setOrganizations(response.items);
          if (response.items.length > 0) {
            setSelectedOrganizationId(response.items[0].organizationId);
          }
        }
      } catch (err) {
        setError('Failed to fetch roles or organizations.');
        console.error('Failed to fetch data:', err);
      }
    };
    fetchRolesAndOrgs();
  }, [userContext?.permissions]);

  const handleCreateInvitation = async () => {
    if (!selectedRoleId) {
      setError('Please select a role.');
      return;
    }

    let organizationId: number | undefined;
    if (userContext?.permissions.includes(Permission.MANAGE_INVITATIONS_GLOBAL)) {
      organizationId = selectedOrganizationId ?? undefined;
    } else {
      organizationId = userContext?.user.organization.organizationId;
    }

    if (!organizationId) {
      setError('Organization ID is not available.');
      return;
    }

    setLoading(true);
    setError(null);
    setInvitationLink(null);

    try {
      const response = await InvitationService.createInvitation(selectedRoleId, organizationId, note);
      const invitationUrl = `${window.location.origin}/register?token=${response.token}`;
      setInvitationLink(invitationUrl);
      onInvitationCreated(invitationUrl);
    } catch (err) {
      setError('Failed to create invitation.');
      console.error('Failed to create invitation:', err);
    } finally {
      setLoading(false);
    }
  };

  if (!userContext?.permissions.includes(Permission.MANAGE_INVITATIONS_ORGANIZATION) && !userContext?.permissions.includes(Permission.MANAGE_INVITATIONS_GLOBAL)) {
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
            className="form-control mb-4"
          />
          <button
            className="btn btn-secondary"
            onClick={onCancel}
          >
            Close
          </button>
        </div>
      ) : (
        <div>
          {userContext?.permissions.includes(Permission.MANAGE_INVITATIONS_GLOBAL) && (
            <div className="mb-4">
              <label htmlFor="orgSelect" className="block text-sm font-medium text-gray-700">
                Select Organization:
              </label>
              <select
                id="orgSelect"
                className="form-select"
                value={selectedOrganizationId || ''}
                onChange={(e) => setSelectedOrganizationId(Number(e.target.value))}
                disabled={loading}
              >
                {organizations.map((org) => (
                  <option key={org.organizationId} value={org.organizationId}>
                    {org.name}
                  </option>
                ))}
              </select>
            </div>
          )}
          <div className="mb-4">
            <label htmlFor="roleSelect" className="block text-sm font-medium text-gray-700">
              Select Role:
            </label>
            <select
              id="roleSelect"
              className="form-select"
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
          <div className="mb-4">
            <label htmlFor="note" className="block text-sm font-medium text-gray-700">
              Note (Optional):
            </label>
            <input
              type="text"
              id="note"
              className="form-control"
              value={note}
              onChange={(e) => setNote(e.target.value)}
              disabled={loading}
            />
          </div>
          <div className="flex justify-end space-x-2">
            <button
              className="btn btn-secondary"
              onClick={onCancel}
              disabled={loading}
            >
              Cancel
            </button>
            <button
              className="btn btn-primary"
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
