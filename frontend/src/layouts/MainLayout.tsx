import React from 'react';
import { NavLink, Outlet } from 'react-router-dom';
import { usePermissions } from '../AuthContext';

interface MainLayoutProps {
  onLogout: () => void;
}

const MainLayout: React.FC<MainLayoutProps> = ({ onLogout }) => {
  const { hasPermission } = usePermissions();

  return (
    <div className="main-layout">
      <nav className="sidebar">
        <ul>
          {hasPermission('VIEW_EVENTS_ORGANIZATION') && <li><NavLink to="/events">Events</NavLink></li>}
          {hasPermission('VIEW_CUSTOMERS_ORGANIZATION') && <li><NavLink to="/customers">Customers</NavLink></li>}
          {hasPermission('VIEW_INVENTORY_ORGANIZATION') && <li><NavLink to="/inventory">Inventory</NavLink></li>}
          {hasPermission('VIEW_REPORTS_ORGANIZATION') && <li><NavLink to="/reports">Reports</NavLink></li>}
          <li><NavLink to="/profile">Profile</NavLink></li>
          {hasPermission('VIEW_ORGANIZATIONS_GLOBAL') && <li><NavLink to="/organizations">Organizations</NavLink></li>}
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
