import type { InventoryItemResponse, CreateInventoryItemRequest, UpdateInventoryItemRequest, TrackInventoryUsageRequest } from '../types/inventory';
import type { StatusResponse, PaginatedResponse } from '../types/common';
import { apiClient } from './apiClient';

export class InventoryService {
  static async getAllInventoryItems(
    limit?: number,
    offset?: number,
    search?: string,
    sortBy?: string,
    sortOrder?: 'asc' | 'desc',
    organizationId?: number
  ): Promise<PaginatedResponse<InventoryItemResponse>> {
    const url = new URL('/api/inventory', window.location.origin);
    if (limit !== undefined) url.searchParams.append('limit', limit.toString());
    if (offset !== undefined) url.searchParams.append('offset', offset.toString());
    if (search) url.searchParams.append('search', search);
    if (sortBy) url.searchParams.append('sortBy', sortBy);
    if (sortOrder) url.searchParams.append('sortOrder', sortOrder);
    if (organizationId) url.searchParams.append('organizationId', organizationId.toString());

    return apiClient<PaginatedResponse<InventoryItemResponse>>(url.toString());
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
