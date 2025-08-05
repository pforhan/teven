import { useState, useEffect } from 'react';
import { BrowserRouter as Router, Routes, Route, Navigate } from 'react-router-dom';
import { AuthService } from './api/AuthService';
import { AuthProvider } from './AuthContext';

import './App.css';
import Auth from './Auth';
import MainLayout from './layouts/MainLayout';
import CreateEventForm from './components/events/CreateEventForm';
import EditEventForm from './components/events/EditEventForm';
import CreateCustomerForm from './components/customers/CreateCustomerForm';
import EditCustomerForm from './components/customers/EditCustomerForm';
import CreateInventoryForm from './components/inventory/CreateInventoryForm';
import EditInventoryForm from './components/inventory/EditInventoryForm';
import EventList from './components/events/EventList';
import CustomerList from './components/customers/CustomerList';
import InventoryList from './components/inventory/InventoryList';
import ReportList from './components/reports/ReportList';
import Profile from './components/profile/Profile';
import OrganizationList from './components/organizations/OrganizationList';
import CreateOrganizationForm from './components/organizations/CreateOrganizationForm';
import EditOrganizationForm from './components/organizations/EditOrganizationForm';
import ProtectedRoute from './components/common/ProtectedRoute';

function App() {
  const [isLoggedIn, setIsLoggedIn] = useState(false);

  useEffect(() => {
    const token = AuthService.getToken();
    if (token) {
      setIsLoggedIn(true);
    }
  }, []);

  const handleLogin = () => {
    setIsLoggedIn(true);
  };

  const handleLogout = () => {
    AuthService.logout();
    setIsLoggedIn(false);
  };

  return (
    <Router>
      <AuthProvider>
        <Routes>
          {!isLoggedIn ? (
            <Route path="/login" element={<Auth onLogin={handleLogin} />} />
          ) : (
            <Route path="/" element={<MainLayout onLogout={handleLogout} />}>
              <Route index element={<Navigate to="/events" />} />
              <Route path="events" element={<ProtectedRoute permission="VIEW_EVENTS_ORGANIZATION"><EventList /></ProtectedRoute>} />
              <Route path="events/create" element={<ProtectedRoute permission="MANAGE_EVENTS_ORGANIZATION"><CreateEventForm /></ProtectedRoute>} />
              <Route path="events/edit/:eventId" element={<ProtectedRoute permission="MANAGE_EVENTS_ORGANIZATION"><EditEventForm /></ProtectedRoute>} />
              <Route path="customers" element={<ProtectedRoute permission="VIEW_CUSTOMERS_ORGANIZATION"><CustomerList /></ProtectedRoute>} />
              <Route path="customers/create" element={<ProtectedRoute permission="MANAGE_CUSTOMERS_ORGANIZATION"><CreateCustomerForm /></ProtectedRoute>} />
              <Route path="customers/edit/:customerId" element={<ProtectedRoute permission="MANAGE_CUSTOMERS_ORGANIZATION"><EditCustomerForm /></ProtectedRoute>} />
              <Route path="inventory" element={<ProtectedRoute permission="VIEW_INVENTORY_ORGANIZATION"><InventoryList /></ProtectedRoute>} />
              <Route path="inventory/create" element={<ProtectedRoute permission="MANAGE_INVENTORY_ORGANIZATION"><CreateInventoryForm /></ProtectedRoute>} />
              <Route path="inventory/edit/:inventoryId" element={<ProtectedRoute permission="MANAGE_INVENTORY_ORGANIZATION"><EditInventoryForm /></ProtectedRoute>} />
              <Route path="reports" element={<ProtectedRoute permission="VIEW_REPORTS_ORGANIZATION"><ReportList /></ProtectedRoute>} />
              <Route path="profile" element={<Profile />} />
              <Route path="organizations" element={<ProtectedRoute permission="VIEW_ORGANIZATIONS_GLOBAL"><OrganizationList /></ProtectedRoute>} />
              <Route path="organizations/create" element={<ProtectedRoute permission="MANAGE_ORGANIZATIONS_GLOBAL"><CreateOrganizationForm /></ProtectedRoute>} />
              <Route path="organizations/edit/:organizationId" element={<ProtectedRoute permission="MANAGE_ORGANIZATIONS_GLOBAL"><EditOrganizationForm /></ProtectedRoute>} />
            </Route>
          )}
          <Route path="*" element={<Navigate to={isLoggedIn ? "/" : "/login"} />} />
        </Routes>
      </AuthProvider>
    </Router>
  );
}

export default App;
