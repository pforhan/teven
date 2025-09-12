// frontend/src/components/customers/EditCustomerForm.tsx

import React, { useState, useEffect } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { CustomerService } from '../../api/CustomerService';
import type { CustomerResponse, UpdateCustomerRequest } from '../../types/customers';
import ErrorDisplay from '../common/ErrorDisplay';

const EditCustomerForm: React.FC = () => {
  const navigate = useNavigate();
  const { customerId } = useParams<{ customerId: string }>();
  const [customer, setCustomer] = useState<CustomerResponse | null>(null);
  const [name, setName] = useState('');
  const [phone, setPhone] = useState('');
  const [address, setAddress] = useState('');
  const [notes, setNotes] = useState('');
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const fetchCustomer = async () => {
      if (!customerId) return;
      try {
        const fetchedCustomer = await CustomerService.getCustomer(parseInt(customerId));
        setCustomer(fetchedCustomer);
        setName(fetchedCustomer.name);
        setPhone(fetchedCustomer.phone);
        setAddress(fetchedCustomer.address);
        setNotes(fetchedCustomer.notes);
      } catch (err) {
        if (err instanceof Error) {
          setError(err.message);
        } else {
          setError('An unknown error occurred');
        }
      }
    };
    fetchCustomer();
  }, [customerId]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);

    if (!customerId) return;

    try {
      const request: UpdateCustomerRequest = {
        name,
        phone,
        address,
        notes,
      };

      await CustomerService.updateCustomer(parseInt(customerId), request);
      navigate('/customers');
    } catch (err) {
      if (err instanceof Error) {
        setError(err.message);
      } else {
        setError('An unknown error occurred');
      }
    }
  };

  if (!customer) {
    return <div>Loading customer...</div>;
  }

  return (
    <div className="card">
      <div className="card-body">
        <h2 className="card-title">Edit Customer: {customer.name}</h2>
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
          <button type="submit" className="btn btn-primary">Update Customer</button>
          <button type="button" className="btn btn-secondary ms-2" onClick={() => navigate('/customers')}>Cancel</button>
        </form>
      </div>
    </div>
  );
};

export default EditCustomerForm;
