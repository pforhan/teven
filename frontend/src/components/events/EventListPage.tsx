import React, { useState, useEffect, useCallback, useMemo } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import { EventService } from '../../api/EventService';
import type { EventResponse } from '../../types/events';
import { usePermissions, useAuth } from '../../AuthContext';
import { useOrganization } from '../../OrganizationContext';
import TableView, { type Column } from '../common/TableView';
import { ApiErrorWithDetails } from '../../errors/ApiErrorWithDetails';
import { FaEdit, FaTrash, FaCheck, FaTimes, FaUndo } from 'react-icons/fa';
import { OverlayTrigger, Tooltip } from 'react-bootstrap';
import QuickOrganizationPickerModal from '../common/QuickOrganizationPickerModal';

const EventListPage: React.FC = () => {
  const navigate = useNavigate();
  const [events, setEvents] = useState<EventResponse[]>([]);
  const [offset, setOffset] = useState(0);
  const [limit] = useState(10);
  const [total, setTotal] = useState(0);
  const [error, setError] = useState<{ message: string; details?: string } | null>(null);
  const { hasPermission } = usePermissions();
  const { userContext } = useAuth();
  const { selectedOrganization } = useOrganization();
  const canManageEvents = hasPermission('MANAGE_EVENTS_ORGANIZATION');
  const [hoveredEventId, setHoveredEventId] = useState<number | null>(null);
  const [showOrgPicker, setShowOrgPicker] = useState(false);
  const [startDate, setStartDate] = useState(() => {
    const today = new Date();
    return today.toISOString().split('T')[0];
  });
  const [sortOrder, setSortOrder] = useState('asc');

  const fetchEvents = useCallback(async () => {
    try {
      const eventData = await EventService.getAllEvents(limit, offset, undefined, startDate, undefined, sortOrder);
      setEvents(eventData.items);
      setTotal(eventData.total);
    } catch (err: unknown) {
      if (err instanceof ApiErrorWithDetails) {
        setError({ message: err.message, details: err.details });
      } else if (err instanceof Error) {
        setError({ message: err.message });
      } else {
        setError({ message: 'An unknown error occurred' });
      }
    }
  }, [limit, offset, startDate, sortOrder]);

  useEffect(() => {
    fetchEvents();
  }, [fetchEvents, offset, startDate, sortOrder]);

  const filteredEvents = useMemo(() => {
    if (!selectedOrganization) {
      return events;
    }
    return events.filter(event => event.organization?.organizationId === selectedOrganization.organizationId);
  }, [events, selectedOrganization]);

  const handleDelete = async (eventId: number | string) => {
    if (typeof eventId !== 'number') return; // Prevent deleting placeholder events
    if (window.confirm('Are you sure you want to delete this event?')) {
      try {
        await EventService.deleteEvent(eventId);
        fetchEvents(); // Re-fetch events after deletion
      } catch (err) {
        if (err instanceof Error) {
          setError({ message: err.message });
        } else {
          setError({ message: 'An unknown error occurred' });
        }
      }
    }
  };

  const handleRsvp = async (eventId: number | string, availability: string) => {
    if (typeof eventId !== 'number') return; // Prevent RSVPing to placeholder events
    try {
      await EventService.rsvpToEvent(eventId, { availability });
      fetchEvents(); // Re-fetch events after RSVP
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

  const columns: Column<EventResponse>[] = [
    {
      key: 'title', label: 'Title', render: (event: EventResponse) => (
        <div className="d-flex justify-content-between align-items-center position-relative">
          {typeof event.eventId === 'number' ? (
            <Link to={`/events/${event.eventId}`}>{event.title}</Link>
          ) : (
            <span>{event.title}</span>
          )}
          {canManageEvents && typeof event.eventId === 'number' && hoveredEventId === event.eventId && (
            <div className="position-absolute top-0 end-0 z-1">
              <OverlayTrigger placement="top" overlay={<Tooltip id={`tooltip-edit-${event.eventId}`}>Edit Event</Tooltip>}>
                <button className="btn btn-sm btn-light me-2" onClick={() => navigate(`/events/edit/${event.eventId}`)}><FaEdit /></button>
              </OverlayTrigger>
              <OverlayTrigger placement="top" overlay={<Tooltip id={`tooltip-delete-${event.eventId}`}>Delete Event</Tooltip>}>
                <button className="btn btn-sm btn-light" onClick={() => handleDelete(event.eventId)}><FaTrash /></button>
              </OverlayTrigger>
            </div>
          )}
        </div>
      )
    },
    { key: 'date', label: 'Date' },
    { key: 'time', label: 'Time' },
    { key: 'description', label: 'Description' },
    { key: 'customer', label: 'Customer', render: (event: EventResponse) => event.customer?.name || 'N/A' },
    {
      key: 'rsvp', label: 'RSVP', render: (event: EventResponse) => {
        const myRsvpStatus = event.rsvps?.find(rsvp => rsvp.userId === userContext?.user?.userId)?.availability;
        return (
          <div>
            <OverlayTrigger placement="top" overlay={<Tooltip id={`tooltip-rsvp-available-${event.eventId}`}>RSVP Yes</Tooltip>}>
              <button
                className={`btn btn-sm me-1 ${myRsvpStatus === 'available' ? 'btn-success' : 'btn-light'}`}
                onClick={() => handleRsvp(event.eventId, 'available')}
              >
                <FaCheck />
              </button>
            </OverlayTrigger>
            <OverlayTrigger placement="top" overlay={<Tooltip id={`tooltip-rsvp-unavailable-${event.eventId}`}>RSVP No</Tooltip>}>
              <button
                className={`btn btn-sm me-1 ${myRsvpStatus === 'unavailable' ? 'btn-danger' : 'btn-light'}`}
                onClick={() => handleRsvp(event.eventId, 'unavailable')}
              >
                <FaTimes />
              </button>
            </OverlayTrigger>
            <OverlayTrigger placement="top" overlay={<Tooltip id={`tooltip-rsvp-clear-${event.eventId}`}>Clear RSVP</Tooltip>}>
              <button
                className="btn btn-sm btn-light"
                onClick={() => handleRsvp(event.eventId, 'no response')}
              >
                <FaUndo />
              </button>
            </OverlayTrigger>
          </div>
        );
      }
    },
  ];

  return (
    <div className="container-fluid">
      <div className="d-flex justify-content-between align-items-center mb-3">
        <h2>Events</h2>
        {canManageEvents && (
          <button
            className="btn btn-primary"
            onClick={() => {
              if (hasPermission('VIEW_USERS_GLOBAL') && !selectedOrganization) {
                setShowOrgPicker(true);
                return;
              }
              navigate('/events/create');
            }}
          >
            Create Event
          </button>
        )}
      </div>

      <QuickOrganizationPickerModal
        show={showOrgPicker}
        onHide={() => setShowOrgPicker(false)}
        onSelect={() => navigate('/events/create')}
      />

      <div className="d-flex justify-content-start mb-3">
        <div className="me-3">
          <label htmlFor="startDate" className="form-label">Start Date</label>
          <input
            type="date"
            id="startDate"
            className="form-control"
            value={startDate}
            onChange={(e) => setStartDate(e.target.value)}
          />
          <button className="btn btn-outline-secondary" type="button" onClick={() => { setStartDate(new Date().toISOString().split('T')[0]); setOffset(0); }}>Today</button>
        </div>
        <div>
          <label htmlFor="sortOrder" className="form-label">Sort Order</label>
          <select
            id="sortOrder"
            className="form-select"
            value={sortOrder}
            onChange={(e) => setSortOrder(e.target.value)}
          >
            <option value="asc">Ascending</option>
            <option value="desc">Descending</option>
          </select>
        </div>
      </div>

      <TableView
        data={filteredEvents}
        columns={columns}
        keyField="eventId"
        error={error}
        onRowMouseEnter={(event) => typeof event.eventId === 'number' && setHoveredEventId(event.eventId)}
        onRowMouseLeave={() => setHoveredEventId(null)}
      />

      <div className="d-flex justify-content-end">
        <button className="btn btn-secondary me-2" onClick={() => setOffset(offset - limit)} disabled={offset === 0}>Previous</button>
        <button className="btn btn-secondary" onClick={() => setOffset(offset + limit)} disabled={offset + limit >= total}>Next</button>
      </div>
      <div className="d-flex justify-content-end">
        <span>Showing {offset + 1} - {Math.min(offset + limit, total)} of {total}</span>
      </div>
    </div>
  );
};

export default EventListPage;
