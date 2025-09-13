import React, { useState, useEffect, useCallback } from 'react';
import { useNavigate } from 'react-router-dom';
import { CustomerService } from '../../api/CustomerService';
import type { CustomerResponse } from '../../types/customers';
import { usePermissions } from '../../AuthContext';
import TableView, { type Column } from '../common/TableView';

const CustomerList: React.FC = () => {
  const navigate = useNavigate();
  const [customers, setCustomers] = useState<CustomerResponse[]>([]);
  const [error, setError] = useState<string | null>(null);
  const { hasPermission } = usePermissions();
  const canManageCustomers = hasPermission('MANAGE_CUSTOMERS_ORGANIZATION');
  const canViewGlobalCustomers = hasPermission('VIEW_CUSTOMERS_GLOBAL');
  const [nameFilter, setNameFilter] = useState('');
  const [sortByName, setSortByName] = useState<'asc' | 'desc' | ''>('');

  const fetchCustomers = useCallback(async () => {
    try {
      const customerData = await CustomerService.getAllCustomers(nameFilter, sortByName === '' ? undefined : sortByName);
      setCustomers(customerData);
    } catch (err) {
      if (err instanceof Error) {
        setError(err.message);
      } else {
        setError('An unknown error occurred');
      }
    }
  }, [nameFilter, sortByName]);

  useEffect(() => {
    fetchCustomers();
  }, [fetchCustomers]);

  const handleDelete = async (customerId: number) => {
    if (window.confirm('Are you sure you want to delete this customer?')) {
      try {
        await CustomerService.deleteCustomer(customerId);
        fetchCustomers(); // Re-fetch customers after deletion
      } catch (err) {
        if (err instanceof Error) {
          setError(err.message);
        } else {
          setError('An unknown error occurred');
        }
      }
    }
  };

  const columns: Column<CustomerResponse>[] = [
    { key: 'name', label: 'Name' },
    { key: 'phone', label: 'Phone' },
    { key: 'address', label: 'Address' },
    { key: 'notes', label: 'Notes' },
    ...(canViewGlobalCustomers ? [{ key: 'organization' as keyof CustomerResponse, label: 'Organization', render: (customer: CustomerResponse) => customer.organization.name }] : []),
  ];

  const renderActions = (customer: CustomerResponse) => (
    <>
      {canManageCustomers && (
        <>
          <button className="btn btn-sm btn-primary me-2" onClick={() => navigate(`/customers/edit/${customer.customerId}`)}>Edit</button>
          <button className="btn btn-sm btn-danger" onClick={() => handleDelete(customer.customerId)}>Delete</button>
        </>
      )}
    </>
  );

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
        title=""
        data={customers}
        columns={columns}
        getKey={(customer) => customer.customerId}
        renderActions={renderActions}
        error={error}
        canView={true} // Assuming anyone who can see the page can view the list
      />
    </div>
  );
};

export default CustomerList;