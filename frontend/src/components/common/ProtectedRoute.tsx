import React from 'react';
import { Navigate } from 'react-router-dom';
import { useAuth, usePermissions } from '../../AuthContext';

interface ProtectedRouteProps {
  children: React.ReactNode;
  permissions: string | string[];
}

const ProtectedRoute: React.FC<ProtectedRouteProps> = ({ children, permissions }) => {
  const { userContext, loading } = useAuth();
  const { hasPermission } = usePermissions();

  if (loading) {
    return <div>Loading...</div>;
  }

  if (!userContext) {
    return <Navigate to="/login" replace />;
  }

  const hasRequiredPermission = Array.isArray(permissions)
    ? permissions.some(p => hasPermission(p))
    : hasPermission(permissions);

  if (!hasRequiredPermission) {
    return <Navigate to="/events" replace />;
  }

  return <>{children}</>;
};

export default ProtectedRoute;
