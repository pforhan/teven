import React, { useState, useEffect } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { EventService } from '../../api/EventService';
import type { EventResponse } from '../../types/events';
import ErrorDisplay from '../common/ErrorDisplay';
import { ApiErrorWithDetails } from '../../errors/ApiErrorWithDetails';
import { useAuth, usePermissions } from '../../AuthContext';

const EventDetails: React.FC = () => {
  const { eventId } = useParams<{ eventId: string }>();
  const navigate = useNavigate();
  const [event, setEvent] = useState<EventResponse | null>(null);
  const [error, setError] = useState<{ message: string; details?: string } | null>(null);
  const [successMessage, setSuccessMessage] = useState<string | null>(null);

  const { userContext } = useAuth();
  const { hasPermission } = usePermissions();
  const canJoinEvents = hasPermission('ASSIGN_TO_EVENTS_SELF');
  const canViewGlobalEvents = hasPermission('VIEW_EVENTS_GLOBAL');

  useEffect(() => {
    const fetchEvent = async () => {
      if (!eventId) return;
      try {
        const fetchedEvent = await EventService.getEvent(parseInt(eventId));
        setEvent(fetchedEvent);
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
    fetchEvent();
  }, [eventId]);

  const handleJoinEvent = async () => {
    if (!eventId || !userContext?.user?.userId) return;
    setError(null);
    setSuccessMessage(null);

    try {
      await EventService.joinEvent(parseInt(eventId));
      setSuccessMessage('Successfully joined the event!');
      // Optionally, refresh event details to show updated RSVP status
      // fetchEvent();
    } catch (err: unknown) {
      if (err instanceof ApiErrorWithDetails) {
        setError({ message: err.message, details: err.details });
      } else if (err instanceof Error) {
        setError({ message: err.message });
      } else {
        setError({ message: 'An unknown error occurred while joining the event' });
      }
    }
  };

  if (!event) {
    return <div>Loading event details...</div>;
  }

  return (
    <div className="card">
      <div className="card-body">
        <h2 className="card-title">Event Details: {event.title}</h2>
        <ErrorDisplay error={error} />
        {successMessage && <div className="alert alert-success">{successMessage}</div>}
        <p><strong>Date:</strong> {event.date}</p>
        <p><strong>Time:</strong> {event.time}</p>
        <p><strong>Location:</strong> {event.location}</p>
        <p><strong>Description:</strong> {event.description}</p>
        <p><strong>Customer:</strong> {event.customer.name}</p>
        {canViewGlobalEvents && <p><strong>Organization:</strong> {event.organization.name}</p>}

        <h3>Inventory Items:</h3>
        {event.inventoryItems.length > 0 ? (
          <ul>
            {event.inventoryItems.map(item => (
              <li key={item.inventoryId}>{item.inventoryId} (Qty: {item.quantity})</li>
            ))}
          </ul>
        ) : (
          <p>No inventory items associated.</p>
        )}

        <h3>Joined Users:</h3>
        {event.joinedUsers.length > 0 ? (
          <ul>
            {event.joinedUsers.map(user => (
              <li key={user.userId}>{user.displayName || user.email}</li>
            ))}
          </ul>
        ) : (
          <p>No users have joined this event yet.</p>
        )}

        {canJoinEvents && (
          <button className="btn btn-primary mt-3" onClick={handleJoinEvent}>Join Event</button>
        )}

        <button className="btn btn-secondary mt-3 ms-2" onClick={() => navigate('/events')}>Back to Events</button>
      </div>
    </div>
  );
};

export default EventDetails;
