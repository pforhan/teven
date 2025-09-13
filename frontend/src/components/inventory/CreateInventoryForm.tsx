// frontend/src/components/inventory/CreateInventoryForm.tsx

import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { InventoryService } from '../../api/InventoryService';
import type { CreateInventoryItemRequest } from '../../types/inventory';
import ErrorDisplay from '../common/ErrorDisplay';
import { ApiErrorWithDetails } from '../../errors/ApiErrorWithDetails';

const CreateInventoryForm: React.FC = () => {
  const navigate = useNavigate();
  const [name, setName] = useState('');
  const [description, setDescription] = useState('');
  const [quantity, setQuantity] = useState(0);
  const [error, setError] = useState<{ message: string; details?: string } | null>(null);

  const handleSubmit = async (event: React.FormEvent) => {
    event.preventDefault();
    setError(null);

    try {
      const request: CreateInventoryItemRequest = {
        name,
        description,
        quantity,
      };

      await InventoryService.createInventoryItem(request);
      navigate('/inventory'); // Redirect to inventory list after creation
    } catch (err: unknown) {
      if (err instanceof ApiErrorWithDetails) {
        setError({ message: err.message, details: err.details });
      } else if (err instanceof Error) {
        setError({ message: err.message });
      } else {
        setError({ message: 'An unknown error occurred' });
      }
    }
  };

  return (
    <div className="card">
      <div className="card-body">
        <h2 className="card-title">Create New Inventory Item</h2>
        <ErrorDisplay error={error} />
        <form onSubmit={handleSubmit}>
          <div className="mb-3">
            <label htmlFor="name" className="form-label">Name:</label>
            <input type="text" id="name" className="form-control" value={name} onChange={(e) => setName(e.target.value)} required />
          </div>
          <div className="mb-3">
            <label htmlFor="description" className="form-label">Description:</label>
            <textarea id="description" className="form-control" value={description} onChange={(e) => setDescription(e.target.value)} required />
          </div>
          <div className="mb-3">
            <label htmlFor="quantity" className="form-label">Quantity:</label>
            <input type="number" id="quantity" className="form-control" value={quantity} onChange={(e) => setQuantity(parseInt(e.target.value))} required />
          </div>
          <button type="submit" className="btn btn-primary">Create Item</button>
          <button type="button" className="btn btn-secondary ms-2" onClick={() => navigate('/inventory')}>Cancel</button>
        </form>
      </div>
    </div>
  );
};

export default CreateInventoryForm;
