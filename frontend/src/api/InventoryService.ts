import type { InventoryItemResponse, CreateInventoryItemRequest, UpdateInventoryItemRequest, TrackInventoryUsageRequest } from '../types/inventory';
import type { StatusResponse } from '../types/common';
import { apiClient } from './apiClient';

export class InventoryService {
  static async getAllInventoryItems(nameFilter?: string, sortByName?: 'asc' | 'desc', organizationId?: number): Promise<InventoryItemResponse[]> {
    const url = new URL('/api/inventory', window.location.origin);
    if (nameFilter) {
      url.searchParams.append('name', nameFilter);
    }
    if (sortByName) {
      url.searchParams.append('sortByDate', sortByName);
    }
    if (organizationId) {
      url.searchParams.append('organizationId', organizationId.toString());
    }
    return apiClient<InventoryItemResponse[]>(url.toString());
  }

  static async getInventoryItem(inventoryId: number): Promise<InventoryItemResponse> {
    return apiClient<InventoryItemResponse>(`/api/inventory/${inventoryId}`);
  }

  static async createInventoryItem(request: CreateInventoryItemRequest): Promise<InventoryItemResponse> {
    return apiClient<InventoryItemResponse>('/api/inventory', {
      method: 'POST',
      body: JSON.stringify(request),
    });
  }

  static async updateInventoryItem(inventoryId: number, request: UpdateInventoryItemRequest): Promise<InventoryItemResponse> {
    return apiClient<InventoryItemResponse>(`/api/inventory/${inventoryId}`, {
      method: 'PUT',
      body: JSON.stringify(request),
    });
  }

  static async deleteInventoryItem(inventoryId: number): Promise<StatusResponse> {
    return apiClient<StatusResponse>(`/api/inventory/${inventoryId}`, { method: 'DELETE' });
  }

  static async trackInventoryUsage(inventoryId: number, request: TrackInventoryUsageRequest): Promise<StatusResponse> {
    return apiClient<StatusResponse>(`/api/inventory/${inventoryId}/usage`, {
      method: 'POST',
      body: JSON.stringify(request),
    });
  }
}
