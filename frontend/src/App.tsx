import { BrowserRouter as Router, Routes, Route, Navigate } from 'react-router-dom';
import { AuthProvider, useAuth } from './AuthContext';

import './App.css';
import Auth from './Auth';
import MainLayout from './layouts/MainLayout';
import CreateEventForm from './components/events/CreateEventForm';
import EditEventForm from './components/events/EditEventForm';
import CreateCustomerForm from './components/customers/CreateCustomerForm';
import EditCustomerForm from './components/customers/EditCustomerForm';
import CreateInventoryForm from './components/inventory/CreateInventoryForm';
import EditInventoryForm from './components/inventory/EditInventoryForm';
import EventListPage from './components/events/EventListPage';
import EventCalendar from './components/events/EventCalendar';
import EventDetails from './components/events/EventDetails';
import CustomerList from './components/customers/CustomerList';
import InventoryList from './components/inventory/InventoryList';
import ReportList from './components/reports/ReportList';
import Profile from './components/profile/Profile';
import OrganizationList from './components/organizations/OrganizationList';
import CreateOrganizationForm from './components/organizations/CreateOrganizationForm';
import EditOrganizationForm from './components/organizations/EditOrganizationForm';
import UserList from './components/users/UserList';
import CreateUserForm from './components/users/CreateUserForm';
import EditUserForm from './components/users/EditUserForm';
import ProtectedRoute from './components/common/ProtectedRoute';
import { Permission } from './types/permissions';

const AppRoutes = () => {
  const { userContext, loading } = useAuth();

  if (loading) {
    return <div>Loading...</div>; // Or a spinner component
  }

  return (
    <Routes>
      {!userContext ? (
        <Route path="/login" element={<Auth />} />
      ) : (
        <Route path="/" element={<MainLayout />}>
          <Route index element={<Navigate to="/events" />} />
          <Route path="events" element={<ProtectedRoute permissions={Permission.VIEW_EVENTS_ORGANIZATION}><EventCalendar /></ProtectedRoute>} />
          <Route path="events/list" element={<ProtectedRoute permissions={Permission.VIEW_EVENTS_ORGANIZATION}><EventListPage /></ProtectedRoute>} />
          <Route path="events/:eventId" element={<ProtectedRoute permissions={Permission.VIEW_EVENTS_ORGANIZATION}><EventDetails /></ProtectedRoute>} />
          <Route path="events/create" element={<ProtectedRoute permissions={Permission.MANAGE_EVENTS_ORGANIZATION}><CreateEventForm /></ProtectedRoute>} />
          <Route path="events/edit/:eventId" element={<ProtectedRoute permissions={Permission.MANAGE_EVENTS_ORGANIZATION}><EditEventForm /></ProtectedRoute>} />
          <Route path="customers" element={<ProtectedRoute permissions={Permission.VIEW_CUSTOMERS_ORGANIZATION}><CustomerList /></ProtectedRoute>} />
          <Route path="customers/create" element={<ProtectedRoute permissions={Permission.MANAGE_CUSTOMERS_ORGANIZATION}><CreateCustomerForm /></ProtectedRoute>} />
          <Route path="customers/edit/:customerId" element={<ProtectedRoute permissions={Permission.MANAGE_CUSTOMERS_ORGANIZATION}><EditCustomerForm /></ProtectedRoute>} />
          <Route path="inventory" element={<ProtectedRoute permissions={Permission.VIEW_INVENTORY_ORGANIZATION}><InventoryList /></ProtectedRoute>} />
          <Route path="inventory/create" element={<ProtectedRoute permissions={Permission.MANAGE_INVENTORY_ORGANIZATION}><CreateInventoryForm /></ProtectedRoute>} />
          <Route path="inventory/edit/:inventoryId" element={<ProtectedRoute permissions={Permission.MANAGE_INVENTORY_ORGANIZATION}><EditInventoryForm /></ProtectedRoute>} />
          <Route path="reports" element={<ProtectedRoute permissions={Permission.VIEW_REPORTS_ORGANIZATION}><ReportList /></ProtectedRoute>} />
          <Route path="profile" element={<Profile />} />
              <Route path="organizations" element={<ProtectedRoute permissions={Permission.VIEW_ORGANIZATIONS_GLOBAL}><OrganizationList /></ProtectedRoute>} />
              <Route path="organizations/create" element={<ProtectedRoute permissions={Permission.MANAGE_ORGANIZATIONS_GLOBAL}><CreateOrganizationForm /></ProtectedRoute>} />
              <Route path="organizations/edit/:organizationId" element={<ProtectedRoute permissions={Permission.MANAGE_ORGANIZATIONS_GLOBAL}><EditOrganizationForm /></ProtectedRoute>} />
              <Route path="users" element={<ProtectedRoute permissions={Permission.VIEW_USERS_ORGANIZATION}><UserList /></ProtectedRoute>} />
              <Route path="users/create" element={<ProtectedRoute permissions={[Permission.MANAGE_USERS_GLOBAL, Permission.MANAGE_USERS_ORGANIZATION]}><CreateUserForm /></ProtectedRoute>} />
              <Route path="users/edit/:userId" element={<ProtectedRoute permissions={Permission.MANAGE_USERS_GLOBAL}><EditUserForm /></ProtectedRoute>} />
            </Route>
          )}
        <Route path="*" element={<Navigate to={userContext ? "/" : "/login"} />} />
      </Routes>
  );
}

function App() {
  return (
    <Router>
      <AuthProvider>
        <AppRoutes />
      </AuthProvider>
    </Router>
  );
}

export default App;
