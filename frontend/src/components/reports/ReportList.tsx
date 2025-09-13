import React, { useState, useEffect } from 'react';
import { ReportService } from '../../api/ReportService';
import type { StaffHoursReportResponse, InventoryUsageReportResponse } from '../../types/reports';
import ErrorDisplay from '../common/ErrorDisplay';
import { ApiErrorWithDetails } from '../../errors/ApiErrorWithDetails';

const ReportList: React.FC = () => {
  const [staffHoursReport, setStaffHoursReport] = useState<StaffHoursReportResponse[]>([]);
  const [inventoryUsageReport, setInventoryUsageReport] = useState<InventoryUsageReportResponse[]>([]);
  const [startDate, setStartDate] = useState('');
  const [endDate, setEndDate] = useState('');
  const [error, setError] = useState<{ message: string; details?: string } | null>(null);

  const fetchStaffHoursReport = async () => {
    try {
      if (startDate && endDate) {
        const report = await ReportService.getStaffHoursReport({ startDate, endDate });
        setStaffHoursReport(report);
        setError(null);
      } else {
        setError({ message: 'Please select both start and end dates for staff hours report.' });
      }
    } catch (err: unknown) {
      if (err instanceof ApiErrorWithDetails) {
        setError({ message: err.message, details: err.details });
      } else if (err instanceof Error) {
        setError({ message: err.message });
      } else {
        setError({ message: 'An unknown error occurred while fetching staff hours report' });
      }
    }
  };

  const fetchInventoryUsageReport = async () => {
    try {
      const report = await ReportService.getInventoryUsageReport();
      setInventoryUsageReport(report);
      setError(null);
    } catch (err: unknown) {
      if (err instanceof ApiErrorWithDetails) {
        setError({ message: err.message, details: err.details });
      } else if (err instanceof Error) {
        setError({ message: err.message });
      } else {
        setError({ message: 'An unknown error occurred while fetching inventory usage report' });
      }
    }
  };

  useEffect(() => {
    fetchInventoryUsageReport();
  }, []);

  return (
    <div className="container-fluid">
      <h2>Reports</h2>
      <ErrorDisplay error={error} />

      <div className="card mb-4">
        <div className="card-body">
          <h3 className="card-title">Staff Hours Report</h3>
          <div className="row mb-3">
            <div className="col-md-6">
              <label htmlFor="startDate" className="form-label">Start Date:</label>
              <input type="date" id="startDate" className="form-control" value={startDate} onChange={(e) => setStartDate(e.target.value)} />
            </div>
            <div className="col-md-6">
              <label htmlFor="endDate" className="form-label">End Date:</label>
              <input type="date" id="endDate" className="form-control" value={endDate} onChange={(e) => setEndDate(e.target.value)} />
            </div>
          </div>
          <button onClick={fetchStaffHoursReport} className="btn btn-primary mb-3">Generate Staff Hours Report</button>
          {staffHoursReport.length > 0 ? (
            <div className="table-responsive">
              <table className="table table-striped table-hover">
                <thead className="table-dark">
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
            </div>
          ) : (
            <p>No staff hours data available for the selected period.</p>
          )}
        </div>
      </div>

      <div className="card">
        <div className="card-body">
          <h3 className="card-title">Inventory Usage Report</h3>
          {inventoryUsageReport.length > 0 ? (
            <div className="table-responsive">
              <table className="table table-striped table-hover">
                <thead className="table-dark">
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
            </div>
          ) : (
            <p>No inventory usage data available.</p>
          )}
        </div>
      </div>
    </div>
  );
};

export default ReportList;
