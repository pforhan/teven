import React from 'react';
import { NavLink, Outlet } from 'react-router-dom';
import { useAuth, usePermissions } from '../AuthContext';

const MainLayout: React.FC = () => {
  const { logout } = useAuth();
  const { hasPermission } = usePermissions();

  return (
    <div>
      <nav className="navbar navbar-expand-lg navbar-dark bg-dark">
        <div className="container-fluid">
          <NavLink className="navbar-brand" to="/">Teven</NavLink>
          <button className="navbar-toggler" type="button" data-bs-toggle="collapse" data-bs-target="#navbarNav" aria-controls="navbarNav" aria-expanded="false" aria-label="Toggle navigation">
            <span className="navbar-toggler-icon"></span>
          </button>
          <div className="collapse navbar-collapse" id="navbarNav">
            <ul className="navbar-nav me-auto mb-2 mb-lg-0">
              {hasPermission('VIEW_EVENTS_ORGANIZATION') && <li className="nav-item"><NavLink className="nav-link" to="/events">Event List</NavLink></li>}
              {hasPermission('VIEW_EVENTS_ORGANIZATION') && <li className="nav-item"><NavLink className="nav-link" to="/events/calendar">Event Calendar</NavLink></li>}
              {hasPermission('VIEW_CUSTOMERS_ORGANIZATION') && <li className="nav-item"><NavLink className="nav-link" to="/customers">Customers</NavLink></li>}
              {hasPermission('VIEW_INVENTORY_ORGANIZATION') && <li className="nav-item"><NavLink className="nav-link" to="/inventory">Inventory</NavLink></li>}
              {hasPermission('VIEW_REPORTS_ORGANIZATION') && <li className="nav-item"><NavLink className="nav-link" to="/reports">Reports</NavLink></li>}
              {hasPermission('VIEW_ORGANIZATIONS_GLOBAL') && <li className="nav-item"><NavLink className="nav-link" to="/organizations">Organizations</NavLink></li>}
              {(hasPermission('VIEW_USERS_ORGANIZATION') || hasPermission('VIEW_USERS_GLOBAL')) && <li className="nav-item"><NavLink className="nav-link" to="/users">Users</NavLink></li>}
            </ul>
            <ul className="navbar-nav">
              <li className="nav-item"><NavLink className="nav-link" to="/profile">Profile</NavLink></li>
              <li className="nav-item"><button className="btn btn-link nav-link" onClick={logout}>Logout</button></li>
            </ul>
          </div>
        </div>
      </nav>
      <main className="container mt-4">
        <Outlet />
      </main>
    </div>
  );
};

export default MainLayout;
