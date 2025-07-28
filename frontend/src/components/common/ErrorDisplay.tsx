// frontend/src/components/common/ErrorDisplay.tsx

import React from 'react';

interface ErrorDisplayProps {
  message: string | null;
}

const ErrorDisplay: React.FC<ErrorDisplayProps> = ({ message }) => {
  if (!message) {
    return null;
  }

  return (
    <div className="error-message">
      <p>Error: {message}</p>
    </div>
  );
};

export default ErrorDisplay;
