import React, { createContext, useContext, useState, useEffect, useCallback } from 'react';
import { useNavigate } from 'react-router-dom';
import { AuthService } from './api/AuthService';
import type { UserContextResponse } from './types/auth';
import { UnauthorizedError } from './errors/UnauthorizedError';

interface AuthContextType {
  userContext: UserContextResponse | null;
  loading: boolean;
  refetchUserContext: () => Promise<void>;
  logout: () => void;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

let isRedirecting = false; // Flag to prevent multiple redirects

export const AuthProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [userContext, setUserContext] = useState<UserContextResponse | null>(null);
  const [loading, setLoading] = useState(true);
  const navigate = useNavigate();

  const logout = useCallback(() => {
    AuthService.logout();
    setUserContext(null);
    navigate('/login');
  }, [navigate]);

  const fetchUserContext = useCallback(async () => {
    const token = AuthService.getToken();
    if (!token) {
      setUserContext(null);
      setLoading(false);
      return;
    }

    try {
      const context = await AuthService.getUserContext();
      setUserContext(context);
    } catch (error) {
      console.error('AuthContext: Error fetching user context:', error);
      if (error instanceof UnauthorizedError) {
        console.log('AuthContext: UnauthorizedError caught.');
        if (!isRedirecting) {
          isRedirecting = true;
          console.log('AuthContext: Redirecting to login due to UnauthorizedError.');
          AuthService.logout();
          console.log('AuthContext: Calling navigate("/login").');
          navigate('/login');
        } else {
          console.log('AuthContext: Already redirecting, skipping further action.');
        }
      } else {
        console.error('AuthContext: Failed to fetch user context (non-UnauthorizedError):', error);
      }
    } finally {
      setLoading(false);
    }
  }, [navigate]);

  useEffect(() => {
    fetchUserContext();
  }, [fetchUserContext]);

  return (
    <AuthContext.Provider value={{ userContext, loading, refetchUserContext: fetchUserContext, logout }}>
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

  const hasPermission = useCallback(
    (permission: string) => userContext?.permissions.includes(permission) ?? false,
    [userContext]
  );

  return {
    permissions: userContext?.permissions || [],
    hasPermission,
  };
};
