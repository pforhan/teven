// frontend/src/types/inventory.ts

export interface InventoryItemResponse {
  inventoryId: number;
  name: string;
  description: string;
  quantity: number;
}

export interface CreateInventoryItemRequest {
  name: string;
  description: string;
  quantity: number;
}

export interface UpdateInventoryItemRequest {
  name?: string;
  description?: string;
  quantity?: number;
}

export interface TrackInventoryUsageRequest {
  eventId: number;
  quantity: number;
}
