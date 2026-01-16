// frontend/src/components/customers/CreateCustomerForm.tsx

import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { CustomerService } from '../../api/CustomerService';
import { OrganizationService } from '../../api/OrganizationService';
import type { CreateCustomerRequest } from '../../types/customers';
import type { OrganizationResponse } from '../../types/organizations';
import ErrorDisplay from '../common/ErrorDisplay';
import { ApiErrorWithDetails } from '../../errors/ApiErrorWithDetails';
import { useAuth, usePermissions } from '../../AuthContext';
import { useOrganization } from '../../OrganizationContext';

const CreateCustomerForm: React.FC = () => {
  const navigate = useNavigate();
  const [name, setName] = useState('');
  const [phone, setPhone] = useState('');
  const [address, setAddress] = useState('');
  const [notes, setNotes] = useState('');
  const [error, setError] = useState<{ message: string; details?: string } | null>(null);
  const [availableOrganizations, setAvailableOrganizations] = useState<OrganizationResponse[]>([]);
  const [selectedOrganizationId, setSelectedOrganizationId] = useState<string>('');

  const { userContext } = useAuth();
  const { hasPermission } = usePermissions();
  const { selectedOrganization } = useOrganization();
  const canManageGlobalCustomers = hasPermission('MANAGE_CUSTOMERS_GLOBAL');

  useEffect(() => {
    const fetchOrganizations = async () => {
      if (!selectedOrganization && canManageGlobalCustomers) {
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
  }, [canManageGlobalCustomers, userContext, selectedOrganization]);

  const handleSubmit = async (event: React.FormEvent) => {
    event.preventDefault();
    setError(null);

    try {
      let organizationIdToUse;
      if (selectedOrganization) {
        organizationIdToUse = selectedOrganization.organizationId;
      } else if (canManageGlobalCustomers) {
        organizationIdToUse = selectedOrganizationId ? parseInt(selectedOrganizationId) : undefined;
      } else {
        organizationIdToUse = userContext?.user?.organization?.organizationId;
      }

      if (organizationIdToUse === undefined) {
        setError({ message: 'Organization must be selected.' });
        return;
      }

      const request: CreateCustomerRequest = {
        name,
        phone,
        address,
        notes,
        organizationId: organizationIdToUse,
      };

      await CustomerService.createCustomer(request);
      navigate('/customers'); // Redirect to customer list after creation
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
        <h2 className="card-title">Create New Customer</h2>
        <ErrorDisplay error={error} />
        <form onSubmit={handleSubmit}>
          <div className="mb-3">
            <label htmlFor="name" className="form-label">Name:</label>
            <input type="text" id="name" className="form-control" value={name} onChange={(e) => setName(e.target.value)} required />
          </div>
          <div className="mb-3">
            <label htmlFor="phone" className="form-label">Phone:</label>
            <input type="text" id="phone" className="form-control" value={phone} onChange={(e) => setPhone(e.target.value)} required />
          </div>
          <div className="mb-3">
            <label htmlFor="address" className="form-label">Address:</label>
            <input type="text" id="address" className="form-control" value={address} onChange={(e) => setAddress(e.target.value)} required />
          </div>
          <div className="mb-3">
            <label htmlFor="notes" className="form-label">Notes:</label>
            <textarea id="notes" className="form-control" value={notes} onChange={(e) => setNotes(e.target.value)} required />
          </div>

          {!selectedOrganization && canManageGlobalCustomers && (
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

          <button type="submit" className="btn btn-primary">Create Customer</button>
          <button type="button" className="btn btn-secondary ms-2" onClick={() => navigate('/customers')}>Cancel</button>
        </form>
      </div>
    </div>
  );
};

export default CreateCustomerForm;
