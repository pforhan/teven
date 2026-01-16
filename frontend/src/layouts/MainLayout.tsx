import React from 'react';
import { NavLink, Outlet } from 'react-router-dom';
import { useAuth, usePermissions } from '../AuthContext';
import { Permission } from '../types/permissions';
import OrganizationSelector from '../components/common/OrganizationSelector';

const MainLayout: React.FC = () => {
  const { logout, userContext } = useAuth();
  const { hasPermission } = usePermissions();
  const isSuperAdmin = hasPermission(Permission.VIEW_USERS_GLOBAL);

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
              {hasPermission(Permission.VIEW_EVENTS_ORGANIZATION) && <li className="nav-item"><NavLink className="nav-link" to="/events">Events</NavLink></li>}
              {hasPermission(Permission.VIEW_CUSTOMERS_ORGANIZATION) && <li className="nav-item"><NavLink className="nav-link" to="/customers">Customers</NavLink></li>}
              {hasPermission(Permission.VIEW_INVENTORY_ORGANIZATION) && <li className="nav-item"><NavLink className="nav-link" to="/inventory">Inventory</NavLink></li>}
              {hasPermission(Permission.VIEW_REPORTS_ORGANIZATION) && <li className="nav-item"><NavLink className="nav-link" to="/reports">Reports</NavLink></li>}
              {hasPermission(Permission.VIEW_ORGANIZATIONS_GLOBAL) && <li className="nav-item"><NavLink className="nav-link" to="/organizations">Organizations</NavLink></li>}
              {(hasPermission(Permission.VIEW_USERS_ORGANIZATION) || hasPermission(Permission.VIEW_USERS_GLOBAL)) && <li className="nav-item"><NavLink className="nav-link" to="/users">Users</NavLink></li>}
            </ul>
            <ul className="navbar-nav">
              {isSuperAdmin ? (
                <li className="nav-item">
                  <OrganizationSelector />
                </li>
              ) : (
                <li className="nav-item">
                  <span className="navbar-text me-3">{userContext?.user?.organization?.name}</span>
                </li>
              )}
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
