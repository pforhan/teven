// frontend/src/components/inventory/CreateInventoryForm.tsx

import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { InventoryService } from '../../api/InventoryService';
import type { CreateInventoryItemRequest } from '../../types/inventory';
import ErrorDisplay from '../common/ErrorDisplay';

const CreateInventoryForm: React.FC = () => {
  const navigate = useNavigate();
  const [name, setName] = useState('');
  const [description, setDescription] = useState('');
  const [quantity, setQuantity] = useState(0);
  const [error, setError] = useState<string | null>(null);

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
        <h2 className="card-title">Create New Inventory Item</h2>
        <ErrorDisplay message={error} />
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
