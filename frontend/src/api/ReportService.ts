import type { StaffHoursReportRequest, StaffHoursReportResponse, InventoryUsageReportResponse } from '../types/reports';
import { apiClient } from './apiClient';

export class ReportService {
  static async getStaffHoursReport(request: StaffHoursReportRequest): Promise<StaffHoursReportResponse[]> {
    const queryParams = new URLSearchParams({
      startDate: request.startDate,
      endDate: request.endDate,
    }).toString();
    return apiClient(`/api/reports/staff_hours?${queryParams}`);
  }

  static async getInventoryUsageReport(): Promise<InventoryUsageReportResponse[]> {
    return apiClient('/api/reports/inventory_usage');
  }
}
