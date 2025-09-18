import React, { useState, useEffect } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { EventService } from '../../api/EventService';
import { OrganizationService } from '../../api/OrganizationService';
import { CustomerService } from '../../api/CustomerService';
import type { EventResponse, UpdateEventRequest, EventInventoryItem } from '../../types/events';
import type { OrganizationResponse } from '../../types/organizations';
import type { CustomerResponse } from '../../types/customers';
import ErrorDisplay from '../common/ErrorDisplay';
import InventoryAssociationEditor from '../common/InventoryAssociationEditor';
import { ApiErrorWithDetails } from '../../errors/ApiErrorWithDetails';
import { usePermissions } from '../../AuthContext';

const EditEventForm: React.FC = () => {
  const navigate = useNavigate();
  const { eventId } = useParams<{ eventId: string }>();
  const [event, setEvent] = useState<EventResponse | null>(null);
  const [title, setTitle] = useState('');
  const [date, setDate] = useState('');
  const [time, setTime] = useState('');
  const [location, setLocation] = useState('');
  const [description, setDescription] = useState('');
  const [inventoryItems, setInventoryItems] = useState<EventInventoryItem[]>([]);
  const [customerId, setCustomerId] = useState('');
  const [openInvitation, setOpenInvitation] = useState(false);
  const [numberOfStaffNeeded, setNumberOfStaffNeeded] = useState(0);
  const [error, setError] = useState<{ message: string; details?: string } | null>(null);
  const [availableOrganizations, setAvailableOrganizations] = useState<OrganizationResponse[]>([]);
  const [selectedOrganizationId, setSelectedOrganizationId] = useState<string>('');
  const [availableCustomers, setAvailableCustomers] = useState<CustomerResponse[]>([]);

  const { hasPermission } = usePermissions();
  const canManageGlobalEvents = hasPermission('MANAGE_EVENTS_GLOBAL');

  useEffect(() => {
    const fetchEventAndOrganizations = async () => {
      if (!eventId) return;
      try {
        const fetchedEvent = await EventService.getEvent(parseInt(eventId));
        setEvent(fetchedEvent);
        setTitle(fetchedEvent.title);
        setDate(fetchedEvent.date);
        setTime(fetchedEvent.time);
        setLocation(fetchedEvent.location || '');
        setDescription(fetchedEvent.description || '');
        setInventoryItems(fetchedEvent.inventoryItems || []);
        setCustomerId(fetchedEvent.customer?.customerId.toString() || '');
        setOpenInvitation(false);
        setNumberOfStaffNeeded(0);

        if (canManageGlobalEvents) {
          const orgs = await OrganizationService.getAllOrganizations();
          setAvailableOrganizations(orgs);
        }
        setSelectedOrganizationId(fetchedEvent.organization?.organizationId.toString() || '');
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
    fetchEventAndOrganizations();
  }, [eventId, canManageGlobalEvents]);

  useEffect(() => {
    const fetchCustomers = async () => {
      if (selectedOrganizationId) {
        console.log('Fetching customers for organizationId:', selectedOrganizationId);
        try {
          const customers = await CustomerService.getAllCustomers(
            undefined,
            'asc',
            parseInt(selectedOrganizationId),
          );
          setAvailableCustomers(customers);
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

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);

    if (!eventId) return;

    try {
      const organizationIdToUse = canManageGlobalEvents
        ? (selectedOrganizationId ? parseInt(selectedOrganizationId) : undefined)
        : undefined; // Organization ID is not sent if not global manager

      const request: UpdateEventRequest = {
        title,
        date,
        time,
        location,
        description,
        inventoryItems,
        customerId: parseInt(customerId),
        staffInvites: {
          openInvitation,
          numberOfStaffNeeded,
        },
        organizationId: organizationIdToUse,
      };

      await EventService.updateEvent(parseInt(eventId), request);
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

  if (!event) {
    return <div>Loading event...</div>;
  }

  return (
    <div className="card">
      <div className="card-body">
        <h2 className="card-title">Edit Event: {event.title}</h2>
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
          </div>
          <div className="mb-3">
            <label htmlFor="location" className="form-label">Location:</label>
            <input type="text" id="location" className="form-control" value={location} onChange={(e) => setLocation(e.target.value)} required />
          </div>
          <div className="mb-3">
            <label htmlFor="description" className="form-label">Description:</label>
            <textarea id="description" className="form-control" value={description} onChange={(e) => setDescription(e.target.value)} required />
          </div>
          <div className="mb-3">
            <InventoryAssociationEditor
              initialInventoryItems={event.inventoryItems || []}
              onInventoryItemsChange={setInventoryItems}
              organizationId={selectedOrganizationId}
            />
          </div>
          <div className="mb-3">
            <label htmlFor="customer" className="form-label">Customer:</label>
            <select
              id="customer"
              className="form-select"
              value={customerId}
              onChange={(e) => {
                setCustomerId(e.target.value);
                console.log('Selected customerId:', e.target.value);
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

          {canManageGlobalEvents && (
            <div className="mb-3">
              <label htmlFor="organization" className="form-label">Organization:</label>
              <select
                id="organization"
                className="form-select"
                value={selectedOrganizationId}
                onChange={(e) => setSelectedOrganizationId(e.target.value)}
              >
                {availableOrganizations.map(org => (
                  <option key={org.organizationId} value={org.organizationId}>
                    {org.name}
                  </option>
                ))}
              </select>
            </div>
          )}

          <div className="mb-3 form-check">
            <input type="checkbox" id="openInvitation" className="form-check-input" checked={openInvitation} onChange={(e) => setOpenInvitation(e.target.checked)} />
            <label htmlFor="openInvitation" className="form-check-label">Open Invitation</label>
          </div>
          <div className="mb-3">
            <label htmlFor="numberOfStaffNeeded" className="form-label">Number of Staff Needed:</label>
            <input type="number" id="numberOfStaffNeeded" className="form-control" value={numberOfStaffNeeded} onChange={(e) => setNumberOfStaffNeeded(parseInt(e.target.value))} required />
          </div>
          <button type="submit" className="btn btn-primary">Update Event</button>
          <button type="button" className="btn btn-secondary ms-2" onClick={() => navigate('/events')}>Cancel</button>
        </form>
      </div>
    </div>
  );
};

export default EditEventForm;