import React, { useState, useEffect, useCallback } from 'react';
import { useNavigate } from 'react-router-dom';
import { InventoryService } from '../../api/InventoryService';
import type { InventoryItemResponse } from '../../types/inventory';
import { usePermissions } from '../../AuthContext';
import ErrorDisplay from '../common/ErrorDisplay';

const InventoryList: React.FC = () => {
  const navigate = useNavigate();
  const [inventoryItems, setInventoryItems] = useState<InventoryItemResponse[]>([]);
  const [error, setError] = useState<string | null>(null);
  const { hasPermission } = usePermissions();
  const [nameFilter, setNameFilter] = useState('');
  const [sortByName, setSortByName] = useState<'asc' | 'desc' | ''>('');

  const fetchInventoryItems = useCallback(async () => {
    try {
      const inventoryData = await InventoryService.getAllInventoryItems(nameFilter, sortByName === '' ? undefined : sortByName);
      setInventoryItems(inventoryData);
    } catch (err) {
      if (err instanceof Error) {
        setError(err.message);
      } else {
        setError('An unknown error occurred');
      }
    }
  }, [nameFilter, sortByName]);

  useEffect(() => {
    fetchInventoryItems();
  }, [fetchInventoryItems]);

  const handleDelete = async (inventoryId: number) => {
    if (window.confirm('Are you sure you want to delete this inventory item?')) {
      try {
        await InventoryService.deleteInventoryItem(inventoryId);
        fetchInventoryItems(); // Re-fetch inventory items after deletion
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
      <h2>Inventory</h2>
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

      {hasPermission('MANAGE_INVENTORY_ORGANIZATION') && (
        <button onClick={() => navigate('/inventory/create')}>Create Item</button>
      )}
      <ul>
        {inventoryItems.map(item => (
          <li key={item.inventoryId}>
            <strong>{item.name}</strong> (Quantity: {item.quantity})
            {hasPermission('MANAGE_INVENTORY_ORGANIZATION') && (
              <>
                <button onClick={() => navigate(`/inventory/edit/${item.inventoryId}`)}>Edit</button>
                <button onClick={() => handleDelete(item.inventoryId)}>Delete</button>
              </>
            )}
          </li>
        ))}
      </ul>
    </div>
  );
};

export default InventoryList;

