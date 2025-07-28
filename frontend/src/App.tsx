import { useState, useEffect } from 'react';
import { BrowserRouter as Router, Routes, Route, Navigate } from 'react-router-dom';
import { AuthService } from './api/AuthService';

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
      <Routes>
        {!isLoggedIn ? (
          <Route path="/login" element={<Auth onLogin={handleLogin} />} />
        ) : (
          <Route path="/" element={<MainLayout onLogout={handleLogout} />}>
            <Route index element={<Navigate to="/events" />} />
            <Route path="events" element={<EventList />} />
            <Route path="events/create" element={<CreateEventForm />} />
            <Route path="events/edit/:eventId" element={<EditEventForm />} />
            <Route path="customers" element={<CustomerList />} />
            <Route path="customers/create" element={<CreateCustomerForm />} />
            <Route path="customers/edit/:customerId" element={<EditCustomerForm />} />
            <Route path="inventory" element={<InventoryList />} />
            <Route path="inventory/create" element={<CreateInventoryForm />} />
            <Route path="inventory/edit/:inventoryId" element={<EditInventoryForm />} />
            <Route path="reports" element={<ReportList />} />
            <Route path="profile" element={<Profile />} />
            <Route path="organizations" element={<OrganizationList />} />
            <Route path="organizations/create" element={<CreateOrganizationForm />} />
            <Route path="organizations/edit/:organizationId" element={<EditOrganizationForm />} />
          </Route>
        )}
        <Route path="*" element={<Navigate to={isLoggedIn ? "/" : "/login"} />} />
      </Routes>
    </Router>
  );
}

export default App;
