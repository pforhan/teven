// frontend/src/api/InventoryService.ts

import type { InventoryItemResponse, CreateInventoryItemRequest, UpdateInventoryItemRequest, TrackInventoryUsageRequest } from '../types/inventory';
import type { StatusResponse } from '../types/common';

export class InventoryService {
  private static getAuthHeaders(): HeadersInit {
    const token = localStorage.getItem('authToken');
    if (!token) {
      throw new Error('Authentication token not found');
    }
    return {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${token}`
    };
  }

  static async getAllInventoryItems(): Promise<InventoryItemResponse[]> {
    const response = await fetch('/api/inventory', {
      method: 'GET',
      headers: InventoryService.getAuthHeaders(),
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
      headers: InventoryService.getAuthHeaders(),
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
      headers: InventoryService.getAuthHeaders(),
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
      headers: InventoryService.getAuthHeaders(),
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
      headers: InventoryService.getAuthHeaders(),
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
      headers: InventoryService.getAuthHeaders(),
      body: JSON.stringify(request),
    });
    if (!response.ok) {
      const errorData = await response.json();
      throw new Error(errorData.message || 'Failed to track inventory usage');
    }
    return response.json();
  }
}
