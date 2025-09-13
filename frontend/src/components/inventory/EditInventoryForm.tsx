import React, { useState, useEffect } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { InventoryService } from '../../api/InventoryService';
import type { InventoryItemResponse, UpdateInventoryItemRequest } from '../../types/inventory';
import ErrorDisplay from '../common/ErrorDisplay';
import { ApiErrorWithDetails } from '../../errors/ApiErrorWithDetails';

const EditInventoryForm: React.FC = () => {
  const navigate = useNavigate();
  const { inventoryId } = useParams<{ inventoryId: string }>();
  const [inventoryItem, setInventoryItem] = useState<InventoryItemResponse | null>(null);
  const [name, setName] = useState('');
  const [description, setDescription] = useState('');
  const [quantity, setQuantity] = useState(0);
  const [error, setError] = useState<{ message: string; details?: string } | null>(null);

  useEffect(() => {
    const fetchInventoryItem = async () => {
      if (!inventoryId) return;
      try {
        const fetchedItem = await InventoryService.getInventoryItem(parseInt(inventoryId));
        setInventoryItem(fetchedItem);
        setName(fetchedItem.name);
        setDescription(fetchedItem.description);
        setQuantity(fetchedItem.quantity);
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
        setError({ message: err.message });
      } else {
        setError({ message: 'An unknown error occurred' });
      }
    }
  };

  if (!inventoryItem) {
    return <div>Loading inventory item...</div>;
  }

  return (
    <div className="card">
      <div className="card-body">
        <h2 className="card-title">Edit Inventory Item: {inventoryItem.name}</h2>
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
          <button type="submit" className="btn btn-primary">Update Item</button>
          <button type="button" className="btn btn-secondary ms-2" onClick={() => navigate('/inventory')}>Cancel</button>
        </form>
      </div>
    </div>
  );
};

export default EditInventoryForm;
