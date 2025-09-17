import React from 'react';
import ErrorDisplay from './ErrorDisplay';

export interface Column<T> {
  key: keyof T | 'actions' | string;
  label: string;
  render?: (item: T) => React.ReactNode;
}

interface TableViewProps<T> {
  data: T[];
  columns: Column<T>[];
  keyField: keyof T;
  error: { message: string; details?: string } | null;
  onRowMouseEnter?: (item: T) => void;
  onRowMouseLeave?: (item: T) => void;
}

const TableView = <T,>({ // eslint-disable-line
  data,
  columns,
  keyField,
  error,
  onRowMouseEnter,
  onRowMouseLeave,
}: TableViewProps<T>) => {


  return (
    <div className="card">
      <div className="card-body">
        <ErrorDisplay error={error} />

        <div className="table-responsive">
          <table className="table table-striped table-hover">
            <thead className="table-dark">
              <tr>
                {columns.map(col => (
                  <th key={col.key as string}>{col.label}</th>
                ))}
              </tr>
            </thead>
            <tbody>
              {data.map(item => (
                <tr
                  key={item[keyField] as string | number}
                  onMouseEnter={() => onRowMouseEnter && onRowMouseEnter(item)}
                  onMouseLeave={() => onRowMouseLeave && onRowMouseLeave(item)}
                >
                  {columns.map(col => (
                    <td key={col.key as string}>
                      {col.render ? col.render(item) : (item[col.key as keyof T] as React.ReactNode)}
                    </td>
                  ))}
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
