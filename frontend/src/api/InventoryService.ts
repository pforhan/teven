// frontend/src/api/InventoryService.ts

import type { InventoryItemResponse, CreateInventoryItemRequest, UpdateInventoryItemRequest, TrackInventoryUsageRequest } from '../types/inventory';
import type { StatusResponse } from '../types/common';
import { AuthService } from './AuthService';

export class InventoryService {
  static async getAllInventoryItems(nameFilter?: string, sortByName?: 'asc' | 'desc'): Promise<InventoryItemResponse[]> {
    const url = new URL('/api/inventory', window.location.origin);
    if (nameFilter) {
      url.searchParams.append('name', nameFilter);
    }
    if (sortByName) {
      url.searchParams.append('sortByName', sortByName);
    }

    const response = await fetch(url.toString(), {
      method: 'GET',
      headers: AuthService.getAuthHeader(),
    });
    if (!response.ok) {
      const errorData = await response.json();
      throw new Error(errorData.message || 'Failed to fetch inventory items');
    }
    return response.json();
  }

  static async getInventoryItem(inventoryId: number): Promise<InventoryItemResponse> {
    const response = await fetch(`/api/inventory/${inventoryId}`, {
      method: 'GET',
      headers: AuthService.getAuthHeader(),
    });
    if (!response.ok) {
      const errorData = await response.json();
      throw new Error(errorData.message || 'Failed to fetch inventory item');
    }
    return response.json();
  }

  static async createInventoryItem(request: CreateInventoryItemRequest): Promise<InventoryItemResponse> {
    const response = await fetch('/api/inventory', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        ...AuthService.getAuthHeader(),
      },
      body: JSON.stringify(request),
    });
    if (!response.ok) {
      const errorData = await response.json();
      throw new Error(errorData.message || 'Failed to create inventory item');
    }
    return response.json();
  }

  static async updateInventoryItem(inventoryId: number, request: UpdateInventoryItemRequest): Promise<InventoryItemResponse> {
    const response = await fetch(`/api/inventory/${inventoryId}`, {
      method: 'PUT',
      headers: {
        'Content-Type': 'application/json',
        ...AuthService.getAuthHeader(),
      },
      body: JSON.stringify(request),
    });
    if (!response.ok) {
      const errorData = await response.json();
      throw new Error(errorData.message || 'Failed to update inventory item');
    }
    return response.json();
  }

  static async deleteInventoryItem(inventoryId: number): Promise<StatusResponse> {
    const response = await fetch(`/api/inventory/${inventoryId}`, {
      method: 'DELETE',
      headers: AuthService.getAuthHeader(),
    });
    if (!response.ok) {
      const errorData = await response.json();
      throw new Error(errorData.message || 'Failed to delete inventory item');
    }
    return response.json();
  }

  static async trackInventoryUsage(inventoryId: number, request: TrackInventoryUsageRequest): Promise<StatusResponse> {
    const response = await fetch(`/api/inventory/${inventoryId}/usage`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        ...AuthService.getAuthHeader(),
      },
      body: JSON.stringify(request),
    });
    if (!response.ok) {
      const errorData = await response.json();
      throw new Error(errorData.message || 'Failed to track inventory usage');
    }
    return response.json();
  }
}
