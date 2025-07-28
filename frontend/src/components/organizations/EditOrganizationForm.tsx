// frontend/src/components/organizations/EditOrganizationForm.tsx

import React, { useState, useEffect } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { OrganizationService } from '../../api/OrganizationService';
import type { OrganizationResponse, UpdateOrganizationRequest } from '../../types/organizations';
import ErrorDisplay from '../common/ErrorDisplay';

const EditOrganizationForm: React.FC = () => {
  const navigate = useNavigate();
  const { organizationId } = useParams<{ organizationId: string }>();
  const [organization, setOrganization] = useState<OrganizationResponse | null>(null);
  const [name, setName] = useState('');
  const [contactInformation, setContactInformation] = useState('');
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const fetchOrganization = async () => {
      if (!organizationId) return;
      try {
        const fetchedOrganization = await OrganizationService.getOrganizationById(parseInt(organizationId));
        setOrganization(fetchedOrganization);
        setName(fetchedOrganization.name);
        setContactInformation(fetchedOrganization.contactInformation);
      } catch (err) {
        if (err instanceof Error) {
          setError(err.message);
        } else {
          setError('An unknown error occurred');
        }
      }
    };
    fetchOrganization();
  }, [organizationId]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);

    if (!organizationId) return;

    try {
      const request: UpdateOrganizationRequest = {
        name,
        contactInformation,
      };

      await OrganizationService.updateOrganization(parseInt(organizationId), request);
      navigate('/organizations');
    } catch (err) {
      if (err instanceof Error) {
        setError(err.message);
      } else {
        setError('An unknown error occurred');
      }
    }
  };

  if (!organization) {
    return <div>Loading organization...</div>;
  }

  return (
    <div>
      <h2>Edit Organization: {organization.name}</h2>
      <ErrorDisplay message={error} />
      <form onSubmit={handleSubmit}>
        <div>
          <label htmlFor="name">Name:</label>
          <input type="text" id="name" value={name} onChange={(e) => setName(e.target.value)} required />
        </div>
        <div>
          <label htmlFor="contactInformation">Contact Information:</label>
          <input type="text" id="contactInformation" value={contactInformation} onChange={(e) => setContactInformation(e.target.value)} required />
        </div>
        <button type="submit">Update Organization</button>
        <button type="button" onClick={() => navigate('/organizations')}>Cancel</button>
      </form>
    </div>
  );
};

export default EditOrganizationForm;
