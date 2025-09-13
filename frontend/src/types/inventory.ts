// frontend/src/types/inventory.ts

import type { OrganizationResponse } from './organizations';

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
  organization: OrganizationResponse;
}

export interface CreateInventoryItemRequest {
  name: string;
  description: string;
  quantity: number;
  organizationId?: number;
}

export interface UpdateInventoryItemRequest {
  name?: string;
  description?: string;
  quantity?: number;
  organizationId?: number;
}

export interface TrackInventoryUsageRequest {
  eventId: number;
  quantity: number;
}