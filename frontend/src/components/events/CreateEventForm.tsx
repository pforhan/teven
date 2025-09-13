import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { EventService } from '../../api/EventService';
import { OrganizationService } from '../../api/OrganizationService';
import type { CreateEventRequest, EventInventoryItem } from '../../types/events';
import type { OrganizationResponse } from '../../types/organizations';
import ErrorDisplay from '../common/ErrorDisplay';
import InventoryAssociationEditor from '../common/InventoryAssociationEditor';
import { ApiErrorWithDetails } from '../../errors/ApiErrorWithDetails';
import { useAuth, usePermissions } from '../../AuthContext';

const CreateEventForm: React.FC = () => {
  const navigate = useNavigate();
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
        location,
        description,
        inventoryIds: inventoryItems.map((item) => item.inventoryId),
        customerId: parseInt(customerId),
        staffInvites: {
          openInvitation,
          numberOfStaffNeeded,
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
              initialInventoryItems={[]}
              onInventoryItemsChange={setInventoryItems}
            />
          </div>
          <div className="mb-3">
            <label htmlFor="customerId" className="form-label">Customer ID:</label>
            <input type="number" id="customerId" className="form-control" value={customerId} onChange={(e) => setCustomerId(e.target.value)} required />
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
