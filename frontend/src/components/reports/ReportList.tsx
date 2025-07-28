// frontend/src/components/reports/ReportList.tsx

import React, { useState, useEffect } from 'react';
import { ReportService } from '../../api/ReportService';
import type { StaffHoursReportResponse, InventoryUsageReportResponse } from '../../types/reports';
import ErrorDisplay from '../common/ErrorDisplay';

const ReportList: React.FC = () => {
  const [staffHoursReport, setStaffHoursReport] = useState<StaffHoursReportResponse[]>([]);
  const [inventoryUsageReport, setInventoryUsageReport] = useState<InventoryUsageReportResponse[]>([]);
  const [startDate, setStartDate] = useState('');
  const [endDate, setEndDate] = useState('');
  const [error, setError] = useState<string | null>(null);

  const fetchStaffHoursReport = async () => {
    try {
      if (startDate && endDate) {
        const report = await ReportService.getStaffHoursReport({ startDate, endDate });
        setStaffHoursReport(report);
        setError(null);
      } else {
        setError('Please select both start and end dates for staff hours report.');
      }
    } catch (err) {
      if (err instanceof Error) {
        setError(err.message);
      } else {
        setError('An unknown error occurred while fetching staff hours report');
      }
    }
  };

  const fetchInventoryUsageReport = async () => {
    try {
      const report = await ReportService.getInventoryUsageReport();
      setInventoryUsageReport(report);
      setError(null);
    } catch (err) {
      if (err instanceof Error) {
        setError(err.message);
      } else {
        setError('An unknown error occurred while fetching inventory usage report');
      }
    }
  };

  useEffect(() => {
    fetchInventoryUsageReport();
  }, []);

  return (
    <div>
      <h2>Reports</h2>
      <ErrorDisplay message={error} />

      <h3>Staff Hours Report</h3>
      <div>
        <label htmlFor="startDate">Start Date:</label>
        <input type="date" id="startDate" value={startDate} onChange={(e) => setStartDate(e.target.value)} />
      </div>
      <div>
        <label htmlFor="endDate">End Date:</label>
        <input type="date" id="endDate" value={endDate} onChange={(e) => setEndDate(e.target.value)} />
      </div>
      <button onClick={fetchStaffHoursReport}>Generate Staff Hours Report</button>
      {staffHoursReport.length > 0 ? (
        <table>
          <thead>
            <tr>
              <th>User ID</th>
              <th>Username</th>
              <th>Total Hours Worked</th>
            </tr>
          </thead>
          <tbody>
            {staffHoursReport.map(item => (
              <tr key={item.userId}>
                <td>{item.userId}</td>
                <td>{item.username}</td>
                <td>{item.totalHoursWorked}</td>
              </tr>
            ))}
          </tbody>
        </table>
      ) : (
        <p>No staff hours data available for the selected period.</p>
      )}

      <h3>Inventory Usage Report</h3>
      {inventoryUsageReport.length > 0 ? (
        <table>
          <thead>
            <tr>
              <th>Inventory ID</th>
              <th>Name</th>
              <th>Usage Count</th>
            </tr>
          </thead>
          <tbody>
            {inventoryUsageReport.map(item => (
              <tr key={item.inventoryId}>
                <td>{item.inventoryId}</td>
                <td>{item.name}</td>
                <td>{item.usageCount}</td>
              </tr>
            ))}
          </tbody>
        </table>
      ) : (
        <p>No inventory usage data available.</p>
      )}
    </div>
  );
};

export default ReportList;
