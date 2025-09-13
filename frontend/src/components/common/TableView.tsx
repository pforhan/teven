import React from 'react';
import ErrorDisplay from './ErrorDisplay';

export interface Column<T> {
  key: keyof T | 'actions';
  label: string;
  render?: (item: T) => React.ReactNode;
}

interface TableViewProps<T> {
  title: string;
  data: T[];
  columns: Column<T>[];
  renderActions?: (item: T) => React.ReactNode;
  createButton?: {
    label: string;
    onClick: () => void;
    permission?: boolean;
  } | null;
  error: { message: string; details?: string } | null;
  canView: boolean;
  viewError?: { message: string; details?: string } | null;
}

const TableView = <T,>({ // eslint-disable-line
  title,
  data,
  columns,
  renderActions,
  createButton,
  error,
  canView,
  viewError,
  getKey,
}: TableViewProps<T> & { getKey: (item: T) => string | number }) => {


  if (!canView) {
    return <ErrorDisplay error={viewError || { message: "Access denied: You do not have permission to view this content." }} />;
  }

  return (
    <div className="card">
      <div className="card-body">
        <h2 className="card-title">{title}</h2>
        <ErrorDisplay error={error} />

        {createButton && createButton.permission && (
          <button className="btn btn-primary mb-3" onClick={createButton.onClick}>{createButton.label}</button>
        )}
        <div className="table-responsive">
          <table className="table table-striped table-hover">
            <thead className="table-dark">
              <tr>
                {columns.map(col => (
                  <th key={col.key as string}>{col.label}</th>
                ))}
                {renderActions && <th>Actions</th>}
              </tr>
            </thead>
            <tbody>
              {data.map(item => (
                <tr key={getKey(item)}>
                  {columns.map(col => (
                    <td key={col.key as string}>
                      {col.render ? col.render(item) : (item[col.key as keyof T] as React.ReactNode)}
                    </td>
                  ))}
                  {renderActions && <td>{renderActions(item)}</td>}
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
};

export default TableView;
