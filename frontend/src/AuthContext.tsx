import React, { createContext, useContext, useState, useEffect } from 'react';
import { AuthService } from './api/AuthService';
import type { UserContextResponse } from './types/auth';

interface AuthContextType {
  userContext: UserContextResponse | null;
  loading: boolean;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

export const AuthProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [userContext, setUserContext] = useState<UserContextResponse | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const fetchUserContext = async () => {
      try {
        const context = await AuthService.getUserContext();
        setUserContext(context);
      } catch (error) {
        console.error('Failed to fetch user context:', error);
      } finally {
        setLoading(false);
      }
    };

    fetchUserContext();
  }, []);

  return (
    <AuthContext.Provider value={{ userContext, loading }}>
      {children}
    </AuthContext.Provider>
  );
};

export const useAuth = () => {
  const context = useContext(AuthContext);
  if (context === undefined) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
};

export const usePermissions = () => {
  const { userContext } = useAuth();
  return {
    permissions: userContext?.permissions || [],
    hasPermission: (permission: string) => userContext?.permissions.includes(permission) ?? false,
  };
};
