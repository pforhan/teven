// frontend/src/components/organizations/OrganizationList.tsx

import React, { useState, useEffect, useCallback } from 'react';
import { useNavigate } from 'react-router-dom';
import { OrganizationService } from '../../api/OrganizationService';
import type { OrganizationResponse } from '../../types/organizations';
import { AuthService } from '../../api/AuthService';
import ErrorDisplay from '../common/ErrorDisplay';

const OrganizationList: React.FC = () => {
  const navigate = useNavigate();
  const [organizations, setOrganizations] = useState<OrganizationResponse[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [userRole, setUserRole] = useState<string | null>(null);

  const fetchOrganizations = useCallback(async () => {
    try {
      const orgData = await OrganizationService.getAllOrganizations();
      setOrganizations(orgData);
    } catch (err) {
      if (err instanceof Error) {
        setError(err.message);
      } else {
        setError('An unknown error occurred');
      }
    }
  }, []);

  useEffect(() => {
    fetchOrganizations();
  }, [fetchOrganizations]);

  useEffect(() => {
    const fetchUserRole = async () => {
      try {
        const context = await AuthService.getUserContext();
        setUserRole(context.user.role);
      } catch (err) {
        console.error('Failed to get user context', err);
      }
    };
    fetchUserRole();
  }, []);

  const handleDelete = async (organizationId: number) => {
    if (window.confirm('Are you sure you want to delete this organization?')) {
      try {
        await OrganizationService.deleteOrganization(organizationId);
        fetchOrganizations(); // Re-fetch organizations after deletion
      } catch (err) {
        if (err instanceof Error) {
          setError(err.message);
        } else {
          setError('An unknown error occurred');
        }
      }
    }
  };

  if (userRole !== 'superadmin') {
    return <ErrorDisplay message="Access denied: SuperAdmin role required to view organizations." />;
  }

  return (
    <div>
      <h2>Organizations</h2>
      <ErrorDisplay message={error} />

      {userRole === 'superadmin' && (
        <button onClick={() => navigate('/organizations/create')}>Create Organization</button>
      )}
      <ul>
        {organizations.map(org => (
          <li key={org.organizationId}>
            <strong>{org.name}</strong> - {org.contactInformation}
            {userRole === 'superadmin' && (
              <>
                <button onClick={() => navigate(`/organizations/edit/${org.organizationId}`)}>Edit</button>
                <button onClick={() => handleDelete(org.organizationId)}>Delete</button>
              </>
            )}
          </li>
        ))}
      </ul>
    </div>
  );
};

export default OrganizationList;
