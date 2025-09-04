import React, { useState, useEffect, useCallback } from 'react';
import { useNavigate } from 'react-router-dom';
import { InventoryService } from '../../api/InventoryService';
import type { InventoryItemResponse } from '../../types/inventory';
import { usePermissions } from '../../AuthContext';
import TableView, { type Column } from '../common/TableView';

const InventoryList: React.FC = () => {
  const navigate = useNavigate();
  const [inventoryItems, setInventoryItems] = useState<InventoryItemResponse[]>([]);
  const [error, setError] = useState<string | null>(null);
  const { hasPermission } = usePermissions();
  const canManageInventory = hasPermission('MANAGE_INVENTORY_ORGANIZATION');
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

  const columns: Column<InventoryItemResponse>[] = [
    { key: 'name', label: 'Name' },
    { key: 'quantity', label: 'Quantity' },
    { key: 'description', label: 'Description' },
    {
      key: 'events',
      label: 'Used in Events',
      render: (item: InventoryItemResponse) => (
        <ul>
          {item.events.map(event => (
            <li key={event.eventId}>ID: {event.eventId} (Qty: {event.quantity})</li>
          ))}
        </ul>
      ),
    },
  ];

  const renderActions = (item: InventoryItemResponse) => (
    <>
      {canManageInventory && (
        <>
          <button onClick={() => navigate(`/inventory/edit/${item.inventoryId}`)}>Edit</button>
          <button onClick={() => handleDelete(item.inventoryId)}>Delete</button>
        </>
      )}
    </>
  );

  return (
    <div>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <h2>Inventory</h2>
        {canManageInventory && (
          <button onClick={() => navigate('/inventory/create')}>Create Item</button>
        )}
      </div>

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

      <TableView
        title=""
        data={inventoryItems}
        columns={columns}
        getKey={(item) => item.inventoryId}
        renderActions={renderActions}
        error={error}
        canView={true} // Assuming anyone who can see the page can view the list
      />
    </div>
  );
};

export default InventoryList;