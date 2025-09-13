import React, { useState, useEffect, useCallback } from 'react';
import { useNavigate } from 'react-router-dom';
import { InventoryService } from '../../api/InventoryService';
import type { InventoryItemResponse } from '../../types/inventory';
import { usePermissions } from '../../AuthContext';
import TableView, { type Column } from '../common/TableView';
import { ApiErrorWithDetails } from '../../errors/ApiErrorWithDetails';

const InventoryList: React.FC = () => {
  const navigate = useNavigate();
  const [inventoryItems, setInventoryItems] = useState<InventoryItemResponse[]>([]);
  const [error, setError] = useState<{ message: string; details?: string } | null>(null);
  const { hasPermission } = usePermissions();
  const canManageInventory = hasPermission('MANAGE_INVENTORY_ORGANIZATION');
  const canViewGlobalInventory = hasPermission('VIEW_INVENTORY_GLOBAL');
  const [nameFilter, setNameFilter] = useState('');
  const [sortByName, setSortByName] = useState<'asc' | 'desc' | ''>('');

  const fetchInventoryItems = useCallback(async () => {
    try {
      const inventoryData = await InventoryService.getAllInventoryItems(nameFilter, sortByName === '' ? undefined : sortByName);
      setInventoryItems(inventoryData);
    } catch (err: unknown) {
      if (err instanceof ApiErrorWithDetails) {
        setError({ message: err.message, details: err.details });
      } else if (err instanceof Error) {
        setError({ message: err.message });
      } else {
        setError({ message: 'An unknown error occurred' });
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
          setError({ message: err.message });
        } else {
          setError({ message: 'An unknown error occurred' });
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
    ...(canViewGlobalInventory ? [{ key: 'organization' as keyof InventoryItemResponse, label: 'Organization', render: (item: InventoryItemResponse) => item.organization.name }] : []),
  ];

  const renderActions = (item: InventoryItemResponse) => (
    <>
      {canManageInventory && (
        <>
          <button className="btn btn-sm btn-primary me-2" onClick={() => navigate(`/inventory/edit/${item.inventoryId}`)}>Edit</button>
          <button className="btn btn-sm btn-danger" onClick={() => handleDelete(item.inventoryId)}>Delete</button>
        </>
      )}
    </>
  );

  return (
    <div className="container-fluid">
      <div className="d-flex justify-content-between align-items-center mb-3">
        <h2>Inventory</h2>
        {canManageInventory && (
          <button className="btn btn-primary" onClick={() => navigate('/inventory/create')}>Create Item</button>
        )}
      </div>

      <div className="row mb-3">
        <div className="col-md-6">
          <label htmlFor="nameFilter" className="form-label">Filter by Name:</label>
          <input
            type="text"
            id="nameFilter"
            className="form-control"
            value={nameFilter}
            onChange={(e) => setNameFilter(e.target.value)}
          />
        </div>
        <div className="col-md-6">
          <label htmlFor="sortByName" className="form-label">Sort by Name:</label>
          <select id="sortByName" className="form-select" value={sortByName} onChange={(e) => setSortByName(e.target.value as 'asc' | 'desc' | '')}>
            <option value="">None</option>
            <option value="asc">Ascending</option>
            <option value="desc">Descending</option>
          </select>
        </div>
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