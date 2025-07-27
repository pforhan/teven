// frontend/src/types/reports.ts

export interface StaffHoursReportRequest {
  startDate: string; // ISO 8601 date string
  endDate: string; // ISO 8601 date string
}

export interface StaffHoursReportResponse {
  userId: number;
  username: string;
  totalHoursWorked: number;
}

export interface InventoryUsageReportResponse {
  inventoryId: number;
  name: string;
  usageCount: number;
}
