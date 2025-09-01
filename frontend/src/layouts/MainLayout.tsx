import React from 'react';
import { NavLink, Outlet, useNavigate } from 'react-router-dom';
import { useAuth, usePermissions } from '../AuthContext';
import { AuthService } from '../api/AuthService';

const MainLayout: React.FC = () => {
  const { hasPermission } = usePermissions();
  const { refetchUserContext } = useAuth();
  const navigate = useNavigate();

  const handleLogout = async () => {
    AuthService.logout();
    await refetchUserContext();
    navigate('/login');
  };

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
          {(hasPermission('VIEW_USERS_ORGANIZATION') || hasPermission('VIEW_USERS_GLOBAL')) && <li><NavLink to="/users">Users</NavLink></li>}
          <li><button onClick={handleLogout}>Logout</button></li>
        </ul>
      </nav>
      <main className="content">
        <Outlet />
      </main>
    </div>
  );
};

export default MainLayout;
