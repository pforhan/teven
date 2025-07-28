// frontend/src/components/customers/CustomerList.tsx

import React, { useState, useEffect, useCallback } from 'react';
import { useNavigate } from 'react-router-dom';
import { CustomerService } from '../../api/CustomerService';
import type { CustomerResponse } from '../../types/customers';
import { AuthService } from '../../api/AuthService';
import ErrorDisplay from '../common/ErrorDisplay';

const CustomerList: React.FC = () => {
  const navigate = useNavigate();
  const [customers, setCustomers] = useState<CustomerResponse[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [userRole, setUserRole] = useState<string | null>(null);
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

  return (
    <div>
      <h2>Customers</h2>
      <ErrorDisplay message={error} />

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

      {userRole === 'organizer' && (
        <button onClick={() => navigate('/customers/create')}>Create Customer</button>
      )}
      <ul>
        {customers.map(customer => (
          <li key={customer.customerId}>
            <strong>{customer.name}</strong> - {customer.contactInformation}
            {userRole === 'organizer' && (
              <>
                <button onClick={() => navigate(`/customers/edit/${customer.customerId}`)}>Edit</button>
                <button onClick={() => handleDelete(customer.customerId)}>Delete</button>
              </>
            )}
          </li>
        ))}
      </ul>
    </div>
  );
};

export default CustomerList;

