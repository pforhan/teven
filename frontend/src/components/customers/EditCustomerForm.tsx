import React, { useState, useEffect } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { CustomerService } from '../../api/CustomerService';
import { OrganizationService } from '../../api/OrganizationService';
import type { CustomerResponse, UpdateCustomerRequest } from '../../types/customers';
import type { OrganizationResponse } from '../../types/organizations';
import ErrorDisplay from '../common/ErrorDisplay';
import { ApiErrorWithDetails } from '../../errors/ApiErrorWithDetails';
import { usePermissions } from '../../AuthContext';

const EditCustomerForm: React.FC = () => {
  const navigate = useNavigate();
  const { customerId } = useParams<{ customerId: string }>();
  const [customer, setCustomer] = useState<CustomerResponse | null>(null);
  const [name, setName] = useState('');
  const [phone, setPhone] = useState('');
  const [address, setAddress] = useState('');
  const [notes, setNotes] = useState('');
  const [error, setError] = useState<{ message: string; details?: string } | null>(null);
  const [availableOrganizations, setAvailableOrganizations] = useState<OrganizationResponse[]>([]);
  const [selectedOrganizationId, setSelectedOrganizationId] = useState<string>('');

  const { hasPermission } = usePermissions();
  const canManageGlobalCustomers = hasPermission('MANAGE_CUSTOMERS_GLOBAL');

  useEffect(() => {
    const fetchCustomerAndOrganizations = async () => {
      if (!customerId) return;
      try {
        const fetchedCustomer = await CustomerService.getCustomer(parseInt(customerId));
        setCustomer(fetchedCustomer);
        setName(fetchedCustomer.name);
        setPhone(fetchedCustomer.phone);
        setAddress(fetchedCustomer.address);
        setNotes(fetchedCustomer.notes);

        if (canManageGlobalCustomers) {
          const orgs = await OrganizationService.getAllOrganizations();
          setAvailableOrganizations(orgs);
        }
        setSelectedOrganizationId(fetchedCustomer.organization.organizationId.toString());
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
    fetchCustomerAndOrganizations();
  }, [customerId, canManageGlobalCustomers]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);

    if (!customerId) return;

    try {
      const organizationIdToUse = canManageGlobalCustomers
        ? (selectedOrganizationId ? parseInt(selectedOrganizationId) : undefined)
        : undefined; // Organization ID is not sent if not global manager

      const request: UpdateCustomerRequest = {
        name,
        phone,
        address,
        notes,
        organizationId: organizationIdToUse,
      };

      await CustomerService.updateCustomer(parseInt(customerId), request);
      navigate('/customers');
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

  if (!customer) {
    return <div>Loading customer...</div>;
  }

  return (
    <div className="card">
      <div className="card-body">
        <h2 className="card-title">Edit Customer: {customer.name}</h2>
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

          {canManageGlobalCustomers && (
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

          <button type="submit" className="btn btn-primary">Update Customer</button>
          <button type="button" className="btn btn-secondary ms-2" onClick={() => navigate('/customers')}>Cancel</button>
        </form>
      </div>
    </div>
  );
};

export default EditCustomerForm;