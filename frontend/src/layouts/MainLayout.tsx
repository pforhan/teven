// frontend/src/layouts/MainLayout.tsx

import React, { useState, useEffect } from 'react';
import { NavLink, Outlet } from 'react-router-dom';
import { AuthService } from '../api/AuthService';

interface MainLayoutProps {
  onLogout: () => void;
}

  const MainLayout: React.FC<MainLayoutProps> = ({ onLogout }) => {
    const [userRole, setUserRole] = useState<string | null>(null);

    useEffect(() => {
      const fetchUserRole = async () => {
        try {
          const context = await AuthService.getUserContext();
          console.log('MainLayout: Fetched user context:', context);
          setUserRole(context.user.role);
          console.log('MainLayout: Set user role to:', context.user.role);
        } catch (err) {
          console.error('MainLayout: Failed to get user context', err);
        }
      };
      fetchUserRole();
    }, []);

    console.log('MainLayout: Current user role state:', userRole);

    return (
    <div className="main-layout">
      <nav className="sidebar">
        <ul>
          <li><NavLink to="/events">Events</NavLink></li>
          <li><NavLink to="/customers">Customers</NavLink></li>
          <li><NavLink to="/inventory">Inventory</NavLink></li>
          <li><NavLink to="/reports">Reports</NavLink></li>
          <li><NavLink to="/profile">Profile</NavLink></li>
          {userRole === 'superadmin' && (
            <li><NavLink to="/organizations">Organizations</NavLink></li>
          )}
          <li><button onClick={onLogout}>Logout</button></li>
        </ul>
      </nav>
      <main className="content">
        <Outlet />
      </main>
    </div>
  );
};

export default MainLayout;
