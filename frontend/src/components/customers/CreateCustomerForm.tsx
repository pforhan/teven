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
    <div className="card">
      <div className="card-body">
        <h2 className="card-title">Create New Customer</h2>
        <ErrorDisplay message={error} />
        <form onSubmit={handleSubmit}>
          <div className="mb-3">
            <label htmlFor="name" className="form-label">Name:</label>
            <input type="text" id="name" className="form-control" value={name} onChange={(e) => setName(e.target.value)} required />
          </div>
          <div className="mb-3">
            <label htmlFor="phone" className="form-label">Phone:</label>
            <input type="text" id="phone" className="form-control" value={phone} onChange={(e) => setPhone(e.target.value)} required />
          </div>
          <div className="mb-3">
            <label htmlFor="address" className="form-label">Address:</label>
            <input type="text" id="address" className="form-control" value={address} onChange={(e) => setAddress(e.target.value)} required />
          </div>
          <div className="mb-3">
            <label htmlFor="notes" className="form-label">Notes:</label>
            <textarea id="notes" className="form-control" value={notes} onChange={(e) => setNotes(e.target.value)} required />
          </div>
          <button type="submit" className="btn btn-primary">Create Customer</button>
          <button type="button" className="btn btn-secondary ms-2" onClick={() => navigate('/customers')}>Cancel</button>
        </form>
      </div>
    </div>
  );
};

export default CreateCustomerForm;
