// frontend/src/types/inventory.ts

export interface EventSummaryResponse {
  eventId: number;
  title: string;
  quantity: number;
}

export interface InventoryItemResponse {
  inventoryId: number;
  name: string;
  description: string;
  quantity: number;
  events: EventSummaryResponse[];
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