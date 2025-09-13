import React, { useState, useEffect } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { OrganizationService } from '../../api/OrganizationService';
import type { OrganizationResponse, UpdateOrganizationRequest } from '../../types/organizations';
import ErrorDisplay from '../common/ErrorDisplay';
import { ApiErrorWithDetails } from '../../errors/ApiErrorWithDetails';

const EditOrganizationForm: React.FC = () => {
  const navigate = useNavigate();
  const { organizationId } = useParams<{ organizationId: string }>();
  const [organization, setOrganization] = useState<OrganizationResponse | null>(null);
  const [name, setName] = useState('');
  const [contactInformation, setContactInformation] = useState('');
  const [error, setError] = useState<{ message: string; details?: string } | null>(null);

  useEffect(() => {
    const fetchOrganization = async () => {
      if (!organizationId) return;
      try {
        const fetchedOrganization = await OrganizationService.getOrganization(parseInt(organizationId));
        setOrganization(fetchedOrganization);
        setName(fetchedOrganization.name);
        setContactInformation(fetchedOrganization.contactInformation);
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
        setError({ message: err.message });
      } else {
        setError({ message: 'An unknown error occurred' });
      }
    }
  };

  if (!organization) {
    return <div>Loading organization...</div>;
  }

  return (
    <div className="card">
      <div className="card-body">
        <h2 className="card-title">Edit Organization: {organization.name}</h2>
        <ErrorDisplay error={error} />
        <form onSubmit={handleSubmit}>
          <div className="mb-3">
            <label htmlFor="name" className="form-label">Name:</label>
            <input type="text" id="name" className="form-control" value={name} onChange={(e) => setName(e.target.value)} required />
          </div>
          <div className="mb-3">
            <label htmlFor="contactInformation" className="form-label">Contact Information:</label>
            <input type="text" id="contactInformation" className="form-control" value={contactInformation} onChange={(e) => setContactInformation(e.target.value)} required />
          </div>
          <button type="submit" className="btn btn-primary">Update Organization</button>
          <button type="button" className="btn btn-secondary ms-2" onClick={() => navigate('/organizations')}>Cancel</button>
        </form>
      </div>
    </div>
  );
};

export default EditOrganizationForm;
