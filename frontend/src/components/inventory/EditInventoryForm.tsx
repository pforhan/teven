import React, { useState, useEffect } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { InventoryService } from '../../api/InventoryService';
import { OrganizationService } from '../../api/OrganizationService';
import type { InventoryItemResponse, UpdateInventoryItemRequest } from '../../types/inventory';
import type { OrganizationResponse } from '../../types/organizations';
import ErrorDisplay from '../common/ErrorDisplay';
import { ApiErrorWithDetails } from '../../errors/ApiErrorWithDetails';
import { usePermissions } from '../../AuthContext';

const EditInventoryForm: React.FC = () => {
  const navigate = useNavigate();
  const { inventoryId } = useParams<{ inventoryId: string }>();
  const [inventoryItem, setInventoryItem] = useState<InventoryItemResponse | null>(null);
  const [name, setName] = useState('');
  const [description, setDescription] = useState('');
  const [quantity, setQuantity] = useState(0);
  const [error, setError] = useState<{ message: string; details?: string } | null>(null);
  const [availableOrganizations, setAvailableOrganizations] = useState<OrganizationResponse[]>([]);
  const [selectedOrganizationId, setSelectedOrganizationId] = useState<string>('');

  const { hasPermission } = usePermissions();
  const canManageGlobalInventory = hasPermission('MANAGE_INVENTORY_GLOBAL');

  useEffect(() => {
    const fetchInventoryItemAndOrganizations = async () => {
      if (!inventoryId) return;
      try {
        const fetchedItem = await InventoryService.getInventoryItem(parseInt(inventoryId));
        setInventoryItem(fetchedItem);
        setName(fetchedItem.name);
        setDescription(fetchedItem.description);
        setQuantity(fetchedItem.quantity);

        if (canManageGlobalInventory) {
          const orgs = await OrganizationService.getAllOrganizations();
          setAvailableOrganizations(orgs);
        }
        setSelectedOrganizationId(fetchedItem.organization.organizationId.toString());
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
    fetchInventoryItemAndOrganizations();
  }, [inventoryId, canManageGlobalInventory]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);

    if (!inventoryId) return;

    try {
      const organizationIdToUse = canManageGlobalInventory
        ? (selectedOrganizationId ? parseInt(selectedOrganizationId) : undefined)
        : undefined; // Organization ID is not sent if not global manager

      const request: UpdateInventoryItemRequest = {
        name,
        description,
        quantity,
        organizationId: organizationIdToUse,
      };

      await InventoryService.updateInventoryItem(parseInt(inventoryId), request);
      navigate('/inventory');
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

  if (!inventoryItem) {
    return <div>Loading inventory item...</div>;
  }

  return (
    <div className="card">
      <div className="card-body">
        <h2 className="card-title">Edit Inventory Item: {inventoryItem.name}</h2>
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

          {canManageGlobalInventory && (
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

          <button type="submit" className="btn btn-primary">Update Item</button>
          <button type="button" className="btn btn-secondary ms-2" onClick={() => navigate('/inventory')}>Cancel</button>
        </form>
      </div>
    </div>
  );
};

export default EditInventoryForm;