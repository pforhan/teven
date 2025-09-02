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
  error: string | null;
  canView: boolean;
  viewError?: string;
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
    return <ErrorDisplay message={viewError || "Access denied: You do not have permission to view this content."} />;
  }

  return (
    <div>
      <h2>{title}</h2>
      <ErrorDisplay message={error} />

      {createButton && createButton.permission && (
        <button onClick={createButton.onClick}>{createButton.label}</button>
      )}
      <table>
        <thead>
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
  );
};

export default TableView;
