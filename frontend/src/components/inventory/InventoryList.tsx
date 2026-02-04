import React, { useState, useEffect, useCallback } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import { FaEdit, FaTrash } from 'react-icons/fa';
import { OverlayTrigger, Tooltip } from 'react-bootstrap';
import { InventoryService } from '../../api/InventoryService';
import type { InventoryItemResponse } from '../../types/inventory';
import { usePermissions } from '../../AuthContext';
import { useOrganization } from '../../OrganizationContext';
import TableView, { type Column } from '../common/TableView';
import { ApiErrorWithDetails } from '../../errors/ApiErrorWithDetails';

const InventoryList: React.FC = () => {
  const navigate = useNavigate();
  const [inventoryItems, setInventoryItems] = useState<InventoryItemResponse[]>([]);
  const [error, setError] = useState<{ message: string; details?: string } | null>(null);
  const { hasPermission } = usePermissions();
  const { selectedOrganization } = useOrganization();
  const canManageInventory = hasPermission('MANAGE_INVENTORY_ORGANIZATION');
  const [search, setSearch] = useState('');
  const [sortBy, setSortBy] = useState<string>('name');
  const [sortOrder, setSortOrder] = useState<'asc' | 'desc'>('asc');
  const [hoveredItemId, setHoveredItemId] = useState<number | null>(null);

  const fetchInventoryItems = useCallback(async () => {
    try {
      const response = await InventoryService.getAllInventoryItems(
        25,
        0,
        search,
        sortBy,
        sortOrder,
        selectedOrganization?.organizationId
      );
      setInventoryItems(response.items);
    } catch (err: unknown) {
      if (err instanceof ApiErrorWithDetails) {
        setError({ message: err.message, details: err.details });
      } else if (err instanceof Error) {
        setError({ message: err.message });
      } else {
        setError({ message: 'An unknown error occurred' });
      }
    }
  }, [search, sortBy, sortOrder, selectedOrganization]);

  useEffect(() => {
    fetchInventoryItems();
  }, [fetchInventoryItems]);

  const handleSort = (key: string) => {
    if (sortBy === key) {
      setSortOrder(sortOrder === 'asc' ? 'desc' : 'asc');
    } else {
      setSortBy(key);
      setSortOrder('asc');
    }
  };

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
    {
      key: 'name', label: 'Name', sortable: true, render: (item: InventoryItemResponse) => (
        <div className="d-flex justify-content-between align-items-center position-relative w-100">
          <Link to={`/inventory/${item.inventoryId}`}>{item.name}</Link>
          {canManageInventory && hoveredItemId === item.inventoryId && (
            <div className="position-absolute top-0 end-0 z-1">
              <OverlayTrigger placement="top" overlay={<Tooltip id={`tooltip-edit-${item.inventoryId}`}>Edit</Tooltip>}>
                <button className="btn btn-sm btn-light me-2" onClick={() => navigate(`/inventory/edit/${item.inventoryId}`)}><FaEdit /></button>
              </OverlayTrigger>
              <OverlayTrigger placement="top" overlay={<Tooltip id={`tooltip-delete-${item.inventoryId}`}>Delete</Tooltip>}>
                <button className="btn btn-sm btn-light" onClick={() => handleDelete(item.inventoryId)}><FaTrash /></button>
              </OverlayTrigger>
            </div>
          )}
        </div>
      )
    },
    { key: 'quantity', label: 'Quantity', sortable: true },
    { key: 'description', label: 'Description' },
    {
      key: 'events',
      label: 'Used in Events',
      render: (item: InventoryItemResponse) => (
        <ul className="mb-0">
          {item.events.map(event => (
            <li key={event.eventId}>ID: {event.eventId} (Qty: {event.quantity})</li>
          ))}
        </ul>
      ),
    },
  ];

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
          <label htmlFor="search" className="form-label">Search:</label>
          <input
            type="text"
            id="search"
            className="form-control"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Search by name..."
          />
        </div>
      </div>

      <TableView
        data={inventoryItems}
        columns={columns}
        keyField="inventoryId"
        error={error}
        onRowMouseEnter={(item) => setHoveredItemId(item.inventoryId)}
        onRowMouseLeave={() => setHoveredItemId(null)}
        sortBy={sortBy}
        sortOrder={sortOrder}
        onSort={handleSort}
      />
    </div>
  );
};

export default InventoryList;