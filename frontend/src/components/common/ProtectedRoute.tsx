import React from 'react';
import { Navigate } from 'react-router-dom';
import { usePermissions } from '../../AuthContext';

interface ProtectedRouteProps {
  permission: string;
  children: React.ReactElement;
}

const ProtectedRoute: React.FC<ProtectedRouteProps> = ({ permission, children }) => {
  const { hasPermission } = usePermissions();

  if (!hasPermission(permission)) {
    return <Navigate to="/" />;
  }

  return children;
};

export default ProtectedRoute;
