// frontend/src/components/inventory/EditInventoryForm.tsx

import React, { useState, useEffect } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { InventoryService } from '../../api/InventoryService';
import type { InventoryItemResponse, UpdateInventoryItemRequest } from '../../types/inventory';
import ErrorDisplay from '../common/ErrorDisplay';

const EditInventoryForm: React.FC = () => {
  const navigate = useNavigate();
  const { inventoryId } = useParams<{ inventoryId: string }>();
  const [inventoryItem, setInventoryItem] = useState<InventoryItemResponse | null>(null);
  const [name, setName] = useState('');
  const [description, setDescription] = useState('');
  const [quantity, setQuantity] = useState(0);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const fetchInventoryItem = async () => {
      if (!inventoryId) return;
      try {
        const fetchedItem = await InventoryService.getInventoryItem(parseInt(inventoryId));
        setInventoryItem(fetchedItem);
        setName(fetchedItem.name);
        setDescription(fetchedItem.description);
        setQuantity(fetchedItem.quantity);
      } catch (err) {
        if (err instanceof Error) {
          setError(err.message);
        } else {
          setError('An unknown error occurred');
        }
      }
    };
    fetchInventoryItem();
  }, [inventoryId]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);

    if (!inventoryId) return;

    try {
      const request: UpdateInventoryItemRequest = {
        name,
        description,
        quantity,
      };

      await InventoryService.updateInventoryItem(parseInt(inventoryId), request);
      navigate('/inventory');
    } catch (err) {
      if (err instanceof Error) {
        setError(err.message);
      } else {
        setError('An unknown error occurred');
      }
    }
  };

  if (!inventoryItem) {
    return <div>Loading inventory item...</div>;
  }

  return (
    <div>
      <h2>Edit Inventory Item: {inventoryItem.name}</h2>
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
        <button type="submit">Update Item</button>
        <button type="button" onClick={() => navigate('/inventory')}>Cancel</button>
      </form>
    </div>
  );
};

export default EditInventoryForm;
