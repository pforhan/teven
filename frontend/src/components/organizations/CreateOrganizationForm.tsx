import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { OrganizationService } from '../../api/OrganizationService';
import type { CreateOrganizationRequest } from '../../types/organizations';
import ErrorDisplay from '../common/ErrorDisplay';
import { ApiErrorWithDetails } from '../../errors/ApiErrorWithDetails';

const CreateOrganizationForm: React.FC = () => {
  const navigate = useNavigate();
  const [name, setName] = useState('');
  const [contactInformation, setContactInformation] = useState('');
  const [error, setError] = useState<{ message: string; details?: string } | null>(null);

  const handleSubmit = async (event: React.FormEvent) => {
    event.preventDefault();
    setError(null);

    try {
      const request: CreateOrganizationRequest = {
        name,
        contactInformation,
      };

      await OrganizationService.createOrganization(request);
      navigate('/organizations'); // Redirect to organization list after creation
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
        <h2 className="card-title">Create New Organization</h2>
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
          <button type="submit" className="btn btn-primary">Create Organization</button>
          <button type="button" className="btn btn-secondary ms-2" onClick={() => navigate('/organizations')}>Cancel</button>
        </form>
      </div>
    </div>
  );
};

export default CreateOrganizationForm;
