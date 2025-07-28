// frontend/src/api/ReportService.ts

import type { StaffHoursReportRequest, StaffHoursReportResponse, InventoryUsageReportResponse } from '../types/reports';

export class ReportService {
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

  static async getStaffHoursReport(request: StaffHoursReportRequest): Promise<StaffHoursReportResponse[]> {
    const queryParams = new URLSearchParams({
      startDate: request.startDate,
      endDate: request.endDate,
    }).toString();
    const response = await fetch(`/api/reports/staff_hours?${queryParams}`, {
      method: 'GET',
      headers: ReportService.getAuthHeaders(),
    });
    if (!response.ok) {
      const errorData = await response.json();
      throw new Error(errorData.message || 'Failed to generate staff hours report');
    }
    return response.json();
  }

  static async getInventoryUsageReport(): Promise<InventoryUsageReportResponse[]> {
    const response = await fetch('/api/reports/inventory_usage', {
      method: 'GET',
      headers: ReportService.getAuthHeaders(),
    });
    if (!response.ok) {
      const errorData = await response.json();
      throw new Error(errorData.message || 'Failed to generate inventory usage report');
    }
    return response.json();
  }
}
