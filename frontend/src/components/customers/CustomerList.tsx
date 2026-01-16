import React, { useState, useEffect, useCallback, useMemo } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import { FaEdit, FaTrash } from 'react-icons/fa';
import { OverlayTrigger, Tooltip } from 'react-bootstrap';
import { CustomerService } from '../../api/CustomerService';
import type { CustomerResponse } from '../../types/customers';
import { usePermissions } from '../../AuthContext';
import { useOrganization } from '../../OrganizationContext';
import TableView, { type Column } from '../common/TableView';
import { ApiErrorWithDetails } from '../../errors/ApiErrorWithDetails';

const CustomerList: React.FC = () => {
  const navigate = useNavigate();
  const [customers, setCustomers] = useState<CustomerResponse[]>([]);
  const [error, setError] = useState<{ message: string; details?: string } | null>(null);
  const { hasPermission } = usePermissions();
  const { selectedOrganization } = useOrganization();
  const canManageCustomers = hasPermission('MANAGE_CUSTOMERS_ORGANIZATION');
  const [nameFilter, setNameFilter] = useState('');
  const [sortByName, setSortByName] = useState<'asc' | 'desc' | ''>('');
  const [hoveredCustomerId, setHoveredCustomerId] = useState<number | null>(null);

  const fetchCustomers = useCallback(async () => {
    try {
      const customerData = await CustomerService.getAllCustomers(nameFilter, sortByName === '' ? undefined : sortByName);
      setCustomers(customerData);
    } catch (err: unknown) {
      if (err instanceof ApiErrorWithDetails) {
        setError({ message: err.message, details: err.details });
      } else if (err instanceof Error) {
        setError({ message: err.message });
      } else {
        setError({ message: 'An unknown error occurred' });
      }
    }
  }, [nameFilter, sortByName]);

  useEffect(() => {
    fetchCustomers();
  }, [fetchCustomers]);

  const filteredCustomers = useMemo(() => {
    if (!selectedOrganization) {
      return customers;
    }
    return customers.filter(customer => customer.organization.organizationId === selectedOrganization.organizationId);
  }, [customers, selectedOrganization]);

  const handleDelete = async (customerId: number) => {
    if (window.confirm('Are you sure you want to delete this customer?')) {
      try {
        await CustomerService.deleteCustomer(customerId);
        fetchCustomers(); // Re-fetch customers after deletion
      } catch (err) {
        if (err instanceof Error) {
          setError({ message: err.message });
        } else {
          setError({ message: 'An unknown error occurred' });
        }
      }
    }
  };

  const columns: Column<CustomerResponse>[] = [
    { key: 'name', label: 'Name', render: (customer: CustomerResponse) => (
      <div className="d-flex justify-content-between align-items-center position-relative">
        <Link to={`/customers/${customer.customerId}`}>{customer.name}</Link>
        {canManageCustomers && hoveredCustomerId === customer.customerId && (
          <div className="position-absolute top-0 end-0 z-1">
            <OverlayTrigger placement="top" overlay={<Tooltip id={`tooltip-edit-${customer.customerId}`}>Edit</Tooltip>}>
              <button className="btn btn-sm btn-light me-2" onClick={() => navigate(`/customers/edit/${customer.customerId}`)}><FaEdit /></button>
            </OverlayTrigger>
            <OverlayTrigger placement="top" overlay={<Tooltip id={`tooltip-delete-${customer.customerId}`}>Delete</Tooltip>}>
              <button className="btn btn-sm btn-light" onClick={() => handleDelete(customer.customerId)}><FaTrash /></button>
            </OverlayTrigger>
          </div>
        )}
      </div>
    ) },
    { key: 'phone', label: 'Phone' },
    { key: 'address', label: 'Address' },
    { key: 'notes', label: 'Notes' },
  ];

  return (
    <div className="container-fluid">
      <div className="d-flex justify-content-between align-items-center mb-3">
        <h2>Customers</h2>
        {canManageCustomers && (
          <button className="btn btn-primary" onClick={() => navigate('/customers/create')}>Create Customer</button>
        )}
      </div>

      <div className="row mb-3">
        <div className="col-md-6">
          <label htmlFor="nameFilter" className="form-label">Filter by Name:</label>
          <input
            type="text"
            id="nameFilter"
            className="form-control"
            value={nameFilter}
            onChange={(e) => setNameFilter(e.target.value)}
          />
        </div>
        <div className="col-md-6">
          <label htmlFor="sortByName" className="form-label">Sort by Name:</label>
          <select id="sortByName" className="form-select" value={sortByName} onChange={(e) => setSortByName(e.target.value as 'asc' | 'desc' | '')}>
            <option value="">None</option>
            <option value="asc">Ascending</option>
            <option value="desc">Descending</option>
          </select>
        </div>
      </div>

      <TableView
        data={filteredCustomers}
        columns={columns}
        keyField="customerId"
        error={error}
        onRowMouseEnter={(customer) => setHoveredCustomerId(customer.customerId)}
        onRowMouseLeave={() => setHoveredCustomerId(null)}
      />
    </div>
  );
};

export default CustomerList;