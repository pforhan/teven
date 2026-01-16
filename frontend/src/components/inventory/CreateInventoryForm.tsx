// frontend/src/components/inventory/CreateInventoryForm.tsx

import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { InventoryService } from '../../api/InventoryService';
import { OrganizationService } from '../../api/OrganizationService';
import type { CreateInventoryItemRequest } from '../../types/inventory';
import type { OrganizationResponse } from '../../types/organizations';
import ErrorDisplay from '../common/ErrorDisplay';
import { ApiErrorWithDetails } from '../../errors/ApiErrorWithDetails';
import { useAuth, usePermissions } from '../../AuthContext';
import { useOrganization } from '../../OrganizationContext';

const CreateInventoryForm: React.FC = () => {
  const navigate = useNavigate();
  const [name, setName] = useState('');
  const [description, setDescription] = useState('');
  const [quantity, setQuantity] = useState(0);
  const [error, setError] = useState<{ message: string; details?: string } | null>(null);
  const [availableOrganizations, setAvailableOrganizations] = useState<OrganizationResponse[]>([]);
  const [selectedOrganizationId, setSelectedOrganizationId] = useState<string>('');

  const { userContext } = useAuth();
  const { hasPermission } = usePermissions();
  const { selectedOrganization } = useOrganization();
  const canManageGlobalInventory = hasPermission('MANAGE_INVENTORY_GLOBAL');

  useEffect(() => {
    const fetchOrganizations = async () => {
      if (!selectedOrganization && canManageGlobalInventory) {
        try {
          const orgs = await OrganizationService.getAllOrganizations();
          setAvailableOrganizations(orgs);
          if (orgs.length > 0) {
            setSelectedOrganizationId(orgs[0].organizationId.toString());
          }
        } catch (err: unknown) {
          if (err instanceof ApiErrorWithDetails) {
            setError({ message: err.message, details: err.details });
          } else if (err instanceof Error) {
            setError({ message: err.message });
          } else {
            setError({ message: 'An unknown error occurred while fetching organizations' });
          }
        }
      } else if (selectedOrganization) {
        setSelectedOrganizationId(selectedOrganization.organizationId.toString());
      } else if (userContext?.user?.organization?.organizationId) {
        setSelectedOrganizationId(userContext.user.organization.organizationId.toString());
      }
    };
    fetchOrganizations();
  }, [canManageGlobalInventory, userContext, selectedOrganization]);

  const handleSubmit = async (event: React.FormEvent) => {
    event.preventDefault();
    setError(null);

    try {
      let organizationIdToUse;
      if (selectedOrganization) {
        organizationIdToUse = selectedOrganization.organizationId;
      } else if (canManageGlobalInventory) {
        organizationIdToUse = selectedOrganizationId ? parseInt(selectedOrganizationId) : undefined;
      } else {
        organizationIdToUse = userContext?.user?.organization?.organizationId;
      }

      if (organizationIdToUse === undefined) {
        setError({ message: 'Organization must be selected.' });
        return;
      }

      const request: CreateInventoryItemRequest = {
        name,
        description,
        quantity,
        organizationId: organizationIdToUse,
      };

      await InventoryService.createInventoryItem(request);
      navigate('/inventory'); // Redirect to inventory list after creation
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
        <h2 className="card-title">Create New Inventory Item</h2>
        <ErrorDisplay error={error} />
        <form onSubmit={handleSubmit}>
          <div className="mb-3">
            <label htmlFor="name" className="form-label">Name:</label>
            <input type="text" id="name" className="form-control" value={name} onChange={(e) => setName(e.target.value)} required />
          </div>
          <div className="mb-3">
            <label htmlFor="description" className="form-label">Description:</label>
            <textarea id="description" className="form-control" value={description} onChange={(e) => setDescription(e.target.value)} required />
          </div>
          <div className="mb-3">
            <label htmlFor="quantity" className="form-label">Quantity:</label>
            <input type="number" id="quantity" className="form-control" value={quantity} onChange={(e) => setQuantity(parseInt(e.target.value))} required />
          </div>

          {!selectedOrganization && canManageGlobalInventory && (
            <div className="mb-3">
              <label htmlFor="organization" className="form-label">Organization:</label>
              <select
                id="organization"
                className="form-select"
                value={selectedOrganizationId}
                onChange={(e) => setSelectedOrganizationId(e.target.value)}
                required
              >
                {availableOrganizations.map(org => (
                  <option key={org.organizationId} value={org.organizationId}>
                    {org.name}
                  </option>
                ))}
              </select>
            </div>
          )}

          <button type="submit" className="btn btn-primary">Create Item</button>
          <button type="button" className="btn btn-secondary ms-2" onClick={() => navigate('/inventory')}>Cancel</button>
        </form>
      </div>
    </div>
  );
};

export default CreateInventoryForm;
