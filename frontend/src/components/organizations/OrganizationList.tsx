import React, { useState, useEffect, useCallback } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import { FaEdit, FaTrash } from 'react-icons/fa';
import { OverlayTrigger, Tooltip } from 'react-bootstrap';
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
  const [hoveredOrgId, setHoveredOrgId] = useState<number | null>(null);

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
    { key: 'name', label: 'Name', render: (org: OrganizationResponse) => (
      <div className="d-flex justify-content-between align-items-center position-relative">
        <Link to={`/organizations/${org.organizationId}`}>{org.name}</Link>
        {canManageOrganizations && hoveredOrgId === org.organizationId && (
          <div className="position-absolute top-0 end-0 z-1">
            <OverlayTrigger placement="top" overlay={<Tooltip id={`tooltip-edit-${org.organizationId}`}>Edit</Tooltip>}>
              <button className="btn btn-sm btn-light me-2" onClick={() => navigate(`/organizations/edit/${org.organizationId}`)}><FaEdit /></button>
            </OverlayTrigger>
            <OverlayTrigger placement="top" overlay={<Tooltip id={`tooltip-delete-${org.organizationId}`}>Delete</Tooltip>}>
              <button className="btn btn-sm btn-light" onClick={() => handleDelete(org.organizationId)}><FaTrash /></button>
            </OverlayTrigger>
          </div>
        )}
      </div>
    ) },
    { key: 'contactInformation', label: 'Contact Information' },
  ];

  return (
    <div className="container-fluid">
      <div className="d-flex justify-content-between align-items-center mb-3">
        <h2>Organizations</h2>
        {canManageOrganizations && (
          <button className="btn btn-primary" onClick={() => navigate('/organizations/create')}>Create Organization</button>
        )}
      </div>

      <TableView
        data={organizations}
        columns={columns}
        keyField="organizationId"
        error={error}
        onRowMouseEnter={(org) => setHoveredOrgId(org.organizationId)}
        onRowMouseLeave={() => setHoveredOrgId(null)}
      />
    </div>
  );
};

export default OrganizationList;