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
    <div>
      <h2>Create New Inventory Item</h2>
      <ErrorDisplay message={error} />
      <form onSubmit={handleSubmit}>
        <div>
          <label htmlFor="name">Name:</label>
          <input type="text" id="name" value={name} onChange={(e) => setName(e.target.value)} required />
        </div>
        <div>
          <label htmlFor="description">Description:</label>
          <textarea id="description" value={description} onChange={(e) => setDescription(e.target.value)} required />
        </div>
        <div>
          <label htmlFor="quantity">Quantity:</label>
          <input type="number" id="quantity" value={quantity} onChange={(e) => setQuantity(parseInt(e.target.value))} required />
        </div>
        <button type="submit">Create Item</button>
        <button type="button" onClick={() => navigate('/inventory')}>Cancel</button>
      </form>
    </div>
  );
};

export default CreateInventoryForm;
