// frontend/src/components/common/ErrorDisplay.tsx

import React, { useState } from 'react';

interface DetailedError {
  message: string;
  details?: string;
}

interface ErrorDisplayProps {
  error: DetailedError | null;
}

const ErrorDisplay: React.FC<ErrorDisplayProps> = ({ error }) => {
  const [showDetails, setShowDetails] = useState(false);

  if (!error) {
    return null;
  }

  return (
    <div className="alert alert-danger" role="alert">
      Error: {error.message}
      {error.details && (
        <div className="mt-2">
          <button
            className="btn btn-sm btn-outline-danger"
            onClick={() => setShowDetails(!showDetails)}
          >
            {showDetails ? 'Hide Details' : 'Show Details'}
          </button>
          {showDetails && (
            <pre className="mt-2 p-2 bg-light border rounded">
              {error.details}
            </pre>
          )}
        </div>
      )}
    </div>
  );
};

export default ErrorDisplay;
