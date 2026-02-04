import React from 'react';
import ErrorDisplay from './ErrorDisplay';
import { FaSort, FaSortUp, FaSortDown } from 'react-icons/fa';

export interface Column<T> {
  key: keyof T | 'actions' | string;
  label: string;
  render?: (item: T) => React.ReactNode;
  sortable?: boolean;
}

interface TableViewProps<T> {
  data: T[];
  columns: Column<T>[];
  keyField: keyof T;
  error: { message: string; details?: string } | null;
  onRowMouseEnter?: (item: T) => void;
  onRowMouseLeave?: (item: T) => void;
  sortBy?: string;
  sortOrder?: 'asc' | 'desc';
  onSort?: (key: string) => void;
}

const TableView = <T,>({ // eslint-disable-line
  data,
  columns,
  keyField,
  error,
  onRowMouseEnter,
  onRowMouseLeave,
  sortBy,
  sortOrder,
  onSort,
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
                  <th
                    key={col.key as string}
                    onClick={() => col.sortable && onSort && onSort(col.key as string)}
                    style={{ cursor: col.sortable ? 'pointer' : 'default', userSelect: 'none' }}
                  >
                    <div className="d-flex align-items-center">
                      {col.label}
                      {col.sortable && (
                        <span className="ms-2">
                          {sortBy === col.key ? (
                            sortOrder === 'asc' ? <FaSortUp /> : <FaSortDown />
                          ) : (
                            <FaSort style={{ opacity: 0.3 }} />
                          )}
                        </span>
                      )}
                    </div>
                  </th>
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
