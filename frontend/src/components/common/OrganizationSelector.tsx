import React, { useState, useEffect } from 'react';
import { useOrganization } from '../../OrganizationContext';
import { OrganizationService } from '../../api/OrganizationService';
import type { OrganizationResponse } from '../../types/organizations';
import { ApiErrorWithDetails } from '../../errors/ApiErrorWithDetails';

const OrganizationSelector: React.FC = () => {
  const { selectedOrganization, setSelectedOrganization } = useOrganization();
  const [organizations, setOrganizations] = useState<OrganizationResponse[]>([]);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const fetchOrganizations = async () => {
      try {
        const response = await OrganizationService.getAllOrganizations(1000);
        setOrganizations(response.items);
      } catch (err) {
        if (err instanceof ApiErrorWithDetails) {
          setError(err.message);
        } else if (err instanceof Error) {
          setError(err.message);
        } else {
          setError('An unknown error occurred');
        }
      }
    };

    fetchOrganizations();
  }, []);

  const handleChange = (event: React.ChangeEvent<HTMLSelectElement>) => {
    const orgId = event.target.value ? parseInt(event.target.value, 10) : null;
    if (orgId === null) {
      setSelectedOrganization(null);
      console.log('OrganizationSelector: Selected organization cleared.');
    } else {
      const organization = organizations.find(org => org.organizationId === orgId);
      setSelectedOrganization(organization || null);
      console.log('OrganizationSelector: Selected organization set to:', organization);
    }
  };

  if (error) {
    return <div className="text-danger">Error: {error}</div>;
  }

  return (
    <select
      className="form-select"
      value={selectedOrganization?.organizationId || ''}
      onChange={handleChange}
      aria-label="Organization Selector"
    >
      <option value="">All Organizations</option>
      {organizations.map(org => (
        <option key={org.organizationId} value={org.organizationId}>
          {org.name}
        </option>
      ))}
    </select>
  );
};

export default OrganizationSelector;
