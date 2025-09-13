import React, { useState, useEffect, useCallback } from 'react';
import { useNavigate } from 'react-router-dom';
import { OrganizationService } from '../../api/OrganizationService';
import type { OrganizationResponse } from '../../types/organizations';
import { usePermissions } from '../../AuthContext';
import TableView, { type Column } from '../common/TableView';
import { ApiErrorWithDetails } from '../../errors/ApiErrorWithDetails';

const OrganizationList: React.FC = () => {
  const navigate = useNavigate();
  const [organizations, setOrganizations] = useState<OrganizationResponse[]>([]);
  const [error, setError] = useState<{ message: string; details?: string } | null>(null);
  const { hasPermission } = usePermissions();
  const canViewOrganizations = hasPermission('VIEW_ORGANIZATIONS_GLOBAL');
  const canManageOrganizations = hasPermission('MANAGE_ORGANIZATIONS_GLOBAL');

  const fetchOrganizations = useCallback(async () => {
    try {
      const orgData = await OrganizationService.getAllOrganizations();
      setOrganizations(orgData);
    } catch (err: unknown) {
      if (err instanceof ApiErrorWithDetails) {
        setError({ message: err.message, details: err.details });
      } else if (err instanceof Error) {
        setError({ message: err.message });
      } else {
        setError({ message: 'An unknown error occurred' });
      }
    }
  }, []);

  useEffect(() => {
    if (canViewOrganizations) {
      fetchOrganizations();
    }
  }, [fetchOrganizations, canViewOrganizations]);

  const handleDelete = async (organizationId: number) => {
    if (window.confirm('Are you sure you want to delete this organization?')) {
      try {
        await OrganizationService.deleteOrganization(organizationId);
        fetchOrganizations(); // Re-fetch organizations after deletion
      } catch (err: unknown) {
        if (err instanceof ApiErrorWithDetails) {
          setError({ message: err.message, details: err.details });
        } else if (err instanceof Error) {
          setError({ message: err.message });
        } else {
          setError({ message: 'An unknown error occurred' });
        }
      }
    }
  };

  const columns: Column<OrganizationResponse>[] = [
    { key: 'name', label: 'Name' },
    { key: 'contactInformation', label: 'Contact Information' },
  ];

  const renderActions = (org: OrganizationResponse) => (
    <>
      {canManageOrganizations && (
        <>
          <button onClick={() => navigate(`/organizations/edit/${org.organizationId}`)}>Edit</button>
          <button onClick={() => handleDelete(org.organizationId)}>Delete</button>
        </>
      )}
    </>
  );

  return (
    <div className="container-fluid">
      <TableView
        title="Organizations"
        data={organizations}
        columns={columns}
        getKey={(org) => org.organizationId}
        renderActions={renderActions}
        createButton={{
          label: 'Create Organization',
          onClick: () => navigate('/organizations/create'),
          permission: canManageOrganizations,
        }}
        error={error}
        canView={canViewOrganizations}
        viewError={{ message: "Access denied: You do not have permission to view organizations." }}
      />
    </div>
  );
};

export default OrganizationList;