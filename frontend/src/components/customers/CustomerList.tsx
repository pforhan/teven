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
  ];

  const renderActions = (customer: CustomerResponse) => (
    <>
      {canManageCustomers && (
        <>
          <button onClick={() => navigate(`/customers/edit/${customer.customerId}`)}>Edit</button>
          <button onClick={() => handleDelete(customer.customerId)}>Delete</button>
        </>
      )}
    </>
  );

  return (
    <div>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <h2>Customers</h2>
        {canManageCustomers && (
          <button onClick={() => navigate('/customers/create')}>Create Customer</button>
        )}
      </div>

      <div>
        <label htmlFor="nameFilter">Filter by Name:</label>
        <input
          type="text"
          id="nameFilter"
          value={nameFilter}
          onChange={(e) => setNameFilter(e.target.value)}
        />
      </div>
      <div>
        <label htmlFor="sortByName">Sort by Name:</label>
        <select id="sortByName" value={sortByName} onChange={(e) => setSortByName(e.target.value as 'asc' | 'desc' | '')}>
          <option value="">None</option>
          <option value="asc">Ascending</option>
          <option value="desc">Descending</option>
        </select>
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