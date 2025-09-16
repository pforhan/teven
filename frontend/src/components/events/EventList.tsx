import React, { useState, useEffect, useCallback } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import { EventService } from '../../api/EventService';
import type { EventResponse } from '../../types/events';
import { usePermissions, useAuth } from '../../AuthContext';
import TableView, { type Column } from '../common/TableView';
import { ApiErrorWithDetails } from '../../errors/ApiErrorWithDetails';
import { FaEdit, FaTrash, FaCheck, FaTimes, FaQuestion } from 'react-icons/fa';

const EventList: React.FC = () => {
  const navigate = useNavigate();
  const [events, setEvents] = useState<EventResponse[]>([]);
  const [offset, setOffset] = useState(0);
  const [limit] = useState(10);
  const [canNextPage, setCanNextPage] = useState(true);
  const [error, setError] = useState<{ message: string; details?: string } | null>(null);
  const { hasPermission } = usePermissions();
  const { userContext } = useAuth();
  const canManageEvents = hasPermission('MANAGE_EVENTS_ORGANIZATION');
  const canViewGlobalEvents = hasPermission('VIEW_EVENTS_GLOBAL');
  

  const fetchEvents = useCallback(async () => {
    try {
      const today = new Date();
      const year = today.getFullYear();
      const month = String(today.getMonth() + 1).padStart(2, '0');
      const day = String(today.getDate()).padStart(2, '0');
      const startDate = `${year}-${month}-${day}`;

      const eventData = await EventService.getAllEvents(limit, offset, undefined, startDate);
      setEvents(eventData);
      setCanNextPage(eventData.length === limit);
    } catch (err: unknown) {
      if (err instanceof ApiErrorWithDetails) {
        setError({ message: err.message, details: err.details });
      } else if (err instanceof Error) {
        setError({ message: err.message });
      } else {
        setError({ message: 'An unknown error occurred' });
      }
    }
  }, [limit, offset]);

  useEffect(() => {
    fetchEvents();
  }, [fetchEvents, offset]);

  const handleDelete = async (eventId: number) => {
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

  const handleRsvp = async (eventId: number, availability: string) => {
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
    { key: 'title', label: 'Title', render: (event: EventResponse) => (
      <div className="d-flex justify-content-between align-items-center">
        <Link to={`/events/${event.eventId}`}>{event.title}</Link>
        {canManageEvents && (
          <div>
            <button className="btn btn-sm btn-light me-2" onClick={() => navigate(`/events/edit/${event.eventId}`)}><FaEdit /></button>
            <button className="btn btn-sm btn-light" onClick={() => handleDelete(event.eventId)}><FaTrash /></button>
          </div>
        )}
      </div>
    ) },
    { key: 'date', label: 'Date' },
    { key: 'time', label: 'Time' },
    { key: 'description', label: 'Description' },
    { key: 'customer', label: 'Customer', render: (event: EventResponse) => event.customer.name },
    ...(canViewGlobalEvents ? [{ key: 'organization' as keyof EventResponse, label: 'Organization', render: (event: EventResponse) => event.organization.name }] : []),
    { key: 'rsvp', label: 'RSVP', render: (event: EventResponse) => {
      const myRsvpStatus = event.rsvps.find(rsvp => rsvp.userId === userContext?.user?.userId)?.availability;
      return (
        <div>
          <button
            className={`btn btn-sm me-1 ${myRsvpStatus === 'available' ? 'btn-success' : 'btn-light'}`}
            onClick={() => handleRsvp(event.eventId, 'available')}
          >
            <FaCheck />
          </button>
          <button
            className={`btn btn-sm me-1 ${myRsvpStatus === 'unavailable' ? 'btn-danger' : 'btn-light'}`}
            onClick={() => handleRsvp(event.eventId, 'unavailable')}
          >
            <FaTimes />
          </button>
          <button
            className="btn btn-sm btn-light"
            onClick={() => handleRsvp(event.eventId, 'no response')}
          >
            <FaQuestion />
          </button>
        </div>
      );
    } },
  ];

  return (
    <div className="container-fluid">
      <div className="d-flex justify-content-between align-items-center mb-3">
        <h2>Events</h2>
        {canManageEvents && (
          <button className="btn btn-primary" onClick={() => navigate('/events/create')}>Create Event</button>
        )}
      </div>

      

      <TableView
        data={events}
        columns={columns}
        keyField="eventId"
        error={error}
      />

      <div className="d-flex justify-content-end">
        <button className="btn btn-secondary me-2" onClick={() => setOffset(offset - limit)} disabled={offset === 0}>Previous</button>
        <button className="btn btn-secondary" onClick={() => setOffset(offset + limit)} disabled={!canNextPage}>Next</button>
      </div>
    </div>
  );
};

export default EventList;
