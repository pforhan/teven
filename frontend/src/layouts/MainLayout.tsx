// frontend/src/layouts/MainLayout.tsx

import React from 'react';
import { NavLink, Outlet } from 'react-router-dom';

interface MainLayoutProps {
  onLogout: () => void;
}

const MainLayout: React.FC<MainLayoutProps> = ({ onLogout }) => {
  return (
    <div className="main-layout">
      <nav className="sidebar">
        <ul>
          <li><NavLink to="/events">Events</NavLink></li>
          <li><NavLink to="/customers">Customers</NavLink></li>
          <li><NavLink to="/inventory">Inventory</NavLink></li>
          <li><NavLink to="/reports">Reports</NavLink></li>
          <li><NavLink to="/profile">Profile</NavLink></li>
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
