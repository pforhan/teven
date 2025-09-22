import React, { useState, useEffect } from 'react';
import { useNavigate, useLocation } from 'react-router-dom';
import { EventService } from '../../api/EventService';
import { OrganizationService } from '../../api/OrganizationService';
import { CustomerService } from '../../api/CustomerService';
import { UserService } from '../../api/UserService';
import type { CreateEventRequest, EventInventoryItem } from '../../types/events';
import type { OrganizationResponse } from '../../types/organizations';
import type { CustomerResponse } from '../../types/customers';
import type { UserResponse } from '../../types/auth';
import ErrorDisplay from '../common/ErrorDisplay';
import InventoryAssociationEditor from '../common/InventoryAssociationEditor';
import { ApiErrorWithDetails } from '../../errors/ApiErrorWithDetails';
import { useAuth, usePermissions } from '../../AuthContext';

const CreateEventForm: React.FC = () => {
  const navigate = useNavigate();
  const location = useLocation();
  const [title, setTitle] = useState('');
  const [date, setDate] = useState('');
  const [time, setTime] = useState('');
  const [durationMinutes, setDurationMinutes] = useState(60);

  useEffect(() => {
    const queryParams = new URLSearchParams(location.search);
    const dateParam = queryParams.get('date');
    const startTimeParam = queryParams.get('startTime');
    const endTimeParam = queryParams.get('endTime');

    if (dateParam) {
      setDate(dateParam);
    }

    if (startTimeParam) {
      setTime(startTimeParam);
    }

    if (dateParam && startTimeParam && endTimeParam) {
      const start = new Date(`${dateParam}T${startTimeParam}`);
      const end = new Date(`${dateParam}T${endTimeParam}`);
      const duration = (end.getTime() - start.getTime()) / 60000; // duration in minutes
      setDurationMinutes(duration);
    } else {
      const timeParam = queryParams.get('time');
      if (timeParam) {
        setTime(timeParam)
      }
    }
  }, [location.search]);
  const [eventLocation, setEventLocation] = useState('');
  const [description, setDescription] = useState('');
  const [inventoryItems, setInventoryItems] = useState<EventInventoryItem[]>([]);
  const [customerId, setCustomerId] = useState('');
  const [openInvitation, setOpenInvitation] = useState(false);
  const [numberOfStaffNeeded, setNumberOfStaffNeeded] = useState(0);
  const [error, setError] = useState<{ message: string; details?: string } | null>(null);
  const [availableOrganizations, setAvailableOrganizations] = useState<OrganizationResponse[]>([]);
  const [selectedOrganizationId, setSelectedOrganizationId] = useState<string>('');
  const [availableCustomers, setAvailableCustomers] = useState<CustomerResponse[]>([]);
  const [availableUsers, setAvailableUsers] = useState<UserResponse[]>([]);
  const [selectedUserIds, setSelectedUserIds] = useState<number[]>([]);

  const { userContext } = useAuth();
  const { hasPermission } = usePermissions();
  const canManageGlobalEvents = hasPermission('MANAGE_EVENTS_GLOBAL');

  useEffect(() => {
    const fetchOrganizations = async () => {
      if (canManageGlobalEvents) {
        try {
          const orgs = await OrganizationService.getAllOrganizations();
          setAvailableOrganizations(orgs);
          if (orgs.length > 0) {
            setSelectedOrganizationId(orgs[0].organizationId.toString());
          }
        } catch (err: unknown) {
          if (err instanceof ApiErrorWithDetails) {
            setError({ message: err.message, details: err.details });
          } else if (err instanceof Error) {
            setError({ message: err.message });
          } else {
            setError({ message: 'An unknown error occurred while fetching organizations' });
          }
        }
      } else if (userContext?.user?.organization?.organizationId) {
        setSelectedOrganizationId(userContext.user.organization.organizationId.toString());
      }
    };
    fetchOrganizations();
  }, [canManageGlobalEvents, userContext]);

  useEffect(() => {
    const fetchCustomers = async () => {
      if (selectedOrganizationId) {
        try {
          const customers = await CustomerService.getAllCustomers(
            undefined,
            'asc',
            parseInt(selectedOrganizationId),
          );
          setAvailableCustomers(customers);
          if (customers.length > 0) {
            setCustomerId(customers[0].customerId.toString());
          } else {
            setCustomerId('');
          }
        } catch (err: unknown) {
          if (err instanceof ApiErrorWithDetails) {
            setError({ message: err.message, details: err.details });
          } else if (err instanceof Error) {
            setError({ message: err.message });
          } else {
            setError({ message: 'An unknown error occurred while fetching customers' });
          }
        }
      }
    };
    fetchCustomers();
  }, [selectedOrganizationId]);

  useEffect(() => {
    const fetchUsers = async () => {
      if (selectedOrganizationId) {
        try {
          const users = await UserService.getAllUsers(parseInt(selectedOrganizationId));
          setAvailableUsers(users);
        } catch (err: unknown) {
          if (err instanceof ApiErrorWithDetails) {
            setError({ message: err.message, details: err.details });
          } else if (err instanceof Error) {
            setError({ message: err.message });
          } else {
            setError({ message: 'An unknown error occurred while fetching users' });
          }
        }
      }
    };
    fetchUsers();
  }, [selectedOrganizationId]);

  const handleSubmit = async (event: React.FormEvent) => {
    event.preventDefault();
    setError(null);

    try {
      const organizationIdToUse = canManageGlobalEvents
        ? (selectedOrganizationId ? parseInt(selectedOrganizationId) : undefined)
        : userContext?.user?.organization?.organizationId;

      if (organizationIdToUse === undefined) {
        setError({ message: 'Organization must be selected.' });
        return;
      }

      const request: CreateEventRequest = {
        title,
        date,
        time,
        durationMinutes,
        location: eventLocation,
        description,
        inventoryItems: inventoryItems,
        customerId: parseInt(customerId),
        staffInvites: {
          openInvitation,
          numberOfStaffNeeded,
          specificStaffIds: selectedUserIds,
        },
        organizationId: organizationIdToUse,
      };

      await EventService.createEvent(request);
      navigate('/events');
    } catch (err: unknown) {
      if (err instanceof ApiErrorWithDetails) {
        setError({ message: err.message, details: err.details });
      } else if (err instanceof Error) {
        setError({ message: err.message });
      } else {
        setError({ message: 'An unknown error occurred' });
      }
    }
  };

  return (
    <div className="card">
      <div className="card-body">
        <h2 className="card-title">Create New Event</h2>
        <ErrorDisplay error={error} />
        <form onSubmit={handleSubmit}>
          <div className="mb-3">
            <label htmlFor="title" className="form-label">Title:</label>
            <input type="text" id="title" className="form-control" value={title} onChange={(e) => setTitle(e.target.value)} required />
          </div>
          <div className="row mb-3">
            <div className="col-md-6">
              <label htmlFor="date" className="form-label">Date:</label>
              <input type="date" id="date" className="form-control" value={date} onChange={(e) => setDate(e.target.value)} required />
            </div>
            <div className="col-md-6">
              <label htmlFor="time" className="form-label">Time:</label>
              <input type="time" id="time" className="form-control" value={time} onChange={(e) => setTime(e.target.value)} required />
            </div>
            <div className="col-md-6">
              <label htmlFor="durationMinutes" className="form-label">Duration (minutes):</label>
              <input type="number" id="durationMinutes" className="form-control" value={durationMinutes} onChange={(e) => setDurationMinutes(parseInt(e.target.value))} required />
            </div>
          </div>
          <div className="mb-3">
            <label htmlFor="eventLocation" className="form-label">Location:</label>
            <input type="text" id="eventLocation" className="form-control" value={eventLocation} onChange={(e) => setEventLocation(e.target.value)} required />
          </div>
          <div className="mb-3">
            <label htmlFor="description" className="form-label">Description:</label>
            <textarea id="description" className="form-control" value={description} onChange={(e) => setDescription(e.target.value)} required />
          </div>
          <div className="mb-3">
            <InventoryAssociationEditor
              initialInventoryItems={[]}
              onInventoryItemsChange={setInventoryItems}
              organizationId={selectedOrganizationId}
            />
          </div>

          {canManageGlobalEvents && (
            <div className="mb-3">
              <label htmlFor="organization" className="form-label">Organization:</label>
              <select
                id="organization"
                className="form-select"
                value={selectedOrganizationId}
                onChange={(e) => setSelectedOrganizationId(e.target.value)}
                required
              >
                {availableOrganizations.map(org => (
                  <option key={org.organizationId} value={org.organizationId}>
                    {org.name}
                  </option>
                ))}
              </select>
            </div>
          )}

          <div className="mb-3">
            <label htmlFor="customer" className="form-label">Customer:</label>
            <select
              id="customer"
              className="form-select"
              value={customerId}
              onChange={(e) => {
                setCustomerId(e.target.value);
              }}
              required
            >
              {availableCustomers.map(customer => (
                <option key={customer.customerId} value={customer.customerId}>
                  {customer.name}
                </option>
              ))}
            </select>
          </div>

          <div className="mb-3">
            <label htmlFor="staffInvites" className="form-label">Invite Staff:</label>
            <select
              id="staffInvites"
              className="form-select"
              multiple
              value={selectedUserIds.map(String)}
              onChange={(e) => setSelectedUserIds(Array.from(e.target.selectedOptions, (option) => parseInt(option.value)))}
            >
              {availableUsers.map(user => (
                <option key={user.userId} value={user.userId}>
                  {user.displayName}
                </option>
              ))}
            </select>
          </div>

          <div className="mb-3 form-check">
            <input type="checkbox" id="openInvitation" className="form-check-input" checked={openInvitation} onChange={(e) => setOpenInvitation(e.target.checked)} />
            <label htmlFor="openInvitation" className="form-check-label">Open Invitation</label>
          </div>
          <div className="mb-3">
            <label htmlFor="numberOfStaffNeeded" className="form-label">Number of Staff Needed:</label>
            <input type="number" id="numberOfStaffNeeded" className="form-control" value={numberOfStaffNeeded} onChange={(e) => setNumberOfStaffNeeded(parseInt(e.target.value))} required />
          </div>
          <button type="submit" className="btn btn-primary">Create Event</button>
          <button type="button" className="btn btn-secondary ms-2" onClick={() => navigate('/events')}>Cancel</button>
        </form>
      </div>
    </div>
  );
};

export default CreateEventForm;
