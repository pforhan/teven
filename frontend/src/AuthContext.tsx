import React, { createContext, useContext, useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { AuthService } from './api/AuthService';
import type { UserContextResponse } from './types/auth';
import { UnauthorizedError } from './errors/UnauthorizedError';

interface AuthContextType {
  userContext: UserContextResponse | null;
  loading: boolean;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

let isRedirecting = false; // Flag to prevent multiple redirects

export const AuthProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [userContext, setUserContext] = useState<UserContextResponse | null>(null);
  const [loading, setLoading] = useState(true);
  const navigate = useNavigate();

  useEffect(() => {
    console.log('AuthContext: useEffect triggered');
    const fetchUserContext = async () => {
      console.log('AuthContext: fetchUserContext called');
      // Prevent fetching user context if we are already on the login page
      // or if a logout has just occurred.
      if (window.location.pathname === '/login') {
        console.log('AuthContext: On login page, skipping user context fetch.');
        setLoading(false);
        return;
      }

      try {
        console.log('AuthContext: Attempting to fetch user context...');
        const context = await AuthService.getUserContext();
        setUserContext(context);
        console.log('AuthContext: User context fetched successfully:', context);
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
        console.log('AuthContext: Loading set to false.');
      }
    };

    fetchUserContext();
  }, [navigate]);

  console.log('AuthContext: Rendered with loading:', loading, 'userContext:', userContext);

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
