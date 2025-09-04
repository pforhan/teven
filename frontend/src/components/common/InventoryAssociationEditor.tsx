import React, { useState, useEffect } from 'react';
import { InventoryService } from '../../api/InventoryService';
import type { InventoryItemResponse } from '../../types/inventory';
import type { EventInventoryItem } from '../../types/events';
import ErrorDisplay from './ErrorDisplay';
import { Link } from 'react-router-dom';

interface InventoryAssociationEditorProps {
  initialInventoryItems: EventInventoryItem[];
  onInventoryItemsChange: (items: EventInventoryItem[]) => void;
}

const InventoryAssociationEditor: React.FC<InventoryAssociationEditorProps> = ({
  initialInventoryItems,
  onInventoryItemsChange,
}) => {
  const [availableInventory, setAvailableInventory] = useState<InventoryItemResponse[]>([]);
  const [selectedInventoryId, setSelectedInventoryId] = useState<string>('');
  const [selectedQuantity, setSelectedQuantity] = useState<number>(1);
  const [currentAssociatedItems, setCurrentAssociatedItems] = useState<EventInventoryItem[]>(initialInventoryItems);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const fetchInventory = async () => {
      try {
        const items = await InventoryService.getAllInventoryItems();
        setAvailableInventory(items);
        if (items.length > 0 && !selectedInventoryId) {
          setSelectedInventoryId(items[0].inventoryId.toString());
        }
      } catch (err) {
        if (err instanceof Error) {
          setError(err.message);
        } else {
          setError('An unknown error occurred while fetching inventory');
        }
      }
    };
    fetchInventory();
  }, [selectedInventoryId]);

  useEffect(() => {
    onInventoryItemsChange(currentAssociatedItems);
  }, [currentAssociatedItems, onInventoryItemsChange]);

  const handleAddItem = () => {
    const inventoryId = parseInt(selectedInventoryId);
    if (isNaN(inventoryId) || selectedQuantity <= 0) {
      setError('Please select a valid inventory item and quantity.');
      return;
    }

    const existingItemIndex = currentAssociatedItems.findIndex(item => item.inventoryId === inventoryId);

    if (existingItemIndex > -1) {
      // Update quantity if item already exists
      const updatedItems = [...currentAssociatedItems];
      updatedItems[existingItemIndex].quantity += selectedQuantity;
      setCurrentAssociatedItems(updatedItems);
    } else {
      // Add new item
      setCurrentAssociatedItems([
        ...currentAssociatedItems,
        { inventoryId, quantity: selectedQuantity },
      ]);
    }
    setError(null);
  };

  const handleRemoveItem = (inventoryId: number) => {
    setCurrentAssociatedItems(currentAssociatedItems.filter(item => item.inventoryId !== inventoryId));
  };

  return (
    <div>
      <h3>Associated Inventory</h3>
      <ErrorDisplay message={error} />

      {availableInventory.length === 0 ? (
        <p>No inventory items available. <Link to="/inventory/create">Create one?</Link></p>
      ) : (
        <div>
          <select
            value={selectedInventoryId}
            onChange={(e) => setSelectedInventoryId(e.target.value)}
          >
            {availableInventory.map(item => (
              <option key={item.inventoryId} value={item.inventoryId}>
                {item.name} (Current Qty: {item.quantity})
              </option>
            ))}
          </select>
          <input
            type="number"
            value={selectedQuantity}
            onChange={(e) => setSelectedQuantity(parseInt(e.target.value) || 1)}
            min="1"
          />
          <button type="button" onClick={handleAddItem}>Add Item</button>
        </div>
      )}

      <ul>
        {currentAssociatedItems.map(item => {
          const inventoryDetail = availableInventory.find(inv => inv.inventoryId === item.inventoryId);
          return (
            <li key={item.inventoryId}>
              {inventoryDetail?.name || `ID: ${item.inventoryId}`} - Quantity: {item.quantity}
              <button type="button" onClick={() => handleRemoveItem(item.inventoryId)}>Remove</button>
            </li>
          );
        })}
      </ul>
    </div>
  );
};

export default InventoryAssociationEditor;
