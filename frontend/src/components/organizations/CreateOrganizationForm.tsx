// frontend/src/components/organizations/CreateOrganizationForm.tsx

import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { OrganizationService } from '../../api/OrganizationService';
import type { CreateOrganizationRequest } from '../../types/organizations';
import ErrorDisplay from '../common/ErrorDisplay';

const CreateOrganizationForm: React.FC = () => {
  const navigate = useNavigate();
  const [name, setName] = useState('');
  const [contactInformation, setContactInformation] = useState('');
  const [error, setError] = useState<string | null>(null);

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
    } catch (err) {
      if (err instanceof Error) {
        setError(err.message);
      } else {
        setError('An unknown error occurred');
      }
    }
  };

  return (
    <div>
      <h2>Create New Organization</h2>
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
        <button type="submit">Create Organization</button>
        <button type="button" onClick={() => navigate('/organizations')}>Cancel</button>
      </form>
    </div>
  );
};

export default CreateOrganizationForm;
