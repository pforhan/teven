// frontend/src/components/customers/CreateCustomerForm.tsx

import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { CustomerService } from '../../api/CustomerService';
import type { CreateCustomerRequest } from '../../types/customers';
import ErrorDisplay from '../common/ErrorDisplay';

const CreateCustomerForm: React.FC = () => {
  const navigate = useNavigate();
  const [name, setName] = useState('');
  const [phone, setPhone] = useState('');
  const [address, setAddress] = useState('');
  const [notes, setNotes] = useState('');
  const [error, setError] = useState<string | null>(null);

  const handleSubmit = async (event: React.FormEvent) => {
    event.preventDefault();
    setError(null);

    try {
      const request: CreateCustomerRequest = {
        name,
        phone,
        address,
        notes,
      };

      await CustomerService.createCustomer(request);
      navigate('/customers'); // Redirect to customer list after creation
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
      <h2>Create New Customer</h2>
      <ErrorDisplay message={error} />
      <form onSubmit={handleSubmit}>
        <div>
          <label htmlFor="name">Name:</label>
          <input type="text" id="name" value={name} onChange={(e) => setName(e.target.value)} required />
        </div>
        <div>
          <label htmlFor="phone">Phone:</label>
          <input type="text" id="phone" value={phone} onChange={(e) => setPhone(e.target.value)} required />
        </div>
        <div>
          <label htmlFor="address">Address:</label>
          <input type="text" id="address" value={address} onChange={(e) => setAddress(e.target.value)} required />
        </div>
        <div>
          <label htmlFor="notes">Notes:</label>
          <textarea id="notes" value={notes} onChange={(e) => setNotes(e.target.value)} required />
        </div>
        <button type="submit">Create Customer</button>
        <button type="button" onClick={() => navigate('/customers')}>Cancel</button>
      </form>
    </div>
  );
};

export default CreateCustomerForm;
