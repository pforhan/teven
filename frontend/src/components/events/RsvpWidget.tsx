import React, { useState, useEffect } from 'react';
import { EventService } from '../../api/EventService';
import type { EventResponse } from '../../types/events';
import { ApiErrorWithDetails } from '../../errors/ApiErrorWithDetails';

const RsvpWidget: React.FC = () => {
  const [rsvps, setRsvps] = useState<EventResponse[]>([]);
  const [error, setError] = useState<{ message: string; details?: string } | null>(null);

  useEffect(() => {
    const fetchRsvps = async () => {
      try {
        const requestedRsvps = await EventService.getRequestedRsvps();
        setRsvps(requestedRsvps);
      } catch (err: unknown) {
        if (err instanceof ApiErrorWithDetails) {
          setError({ message: err.message, details: err.details });
        } else if (err instanceof Error) {
          setError({ message: err.message });
        } else {
          setError({ message: 'An unknown error occurred while fetching RSVPs' });
        }
      }
    };
    fetchRsvps();
  }, []);

  const handleRsvp = async (eventId: number, availability: string) => {
    try {
      await EventService.rsvpToEvent(eventId, { availability });
      setRsvps(rsvps.filter(rsvp => rsvp.eventId !== eventId));
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

  if (rsvps.length === 0) {
    return null;
  }

  return (
    <div className="card mb-4">
      <div className="card-body">
        <h5 className="card-title">You have pending RSVP requests</h5>
        {error && <div className="alert alert-danger">{error.message}</div>}
        <ul className="list-group">
          {rsvps.map(rsvp => (
            <li key={rsvp.eventId} className="list-group-item d-flex justify-content-between align-items-center">
              <div>
                <strong>{rsvp.title}</strong>
                <br />
                <small>{rsvp.date} at {rsvp.time}</small>
              </div>
              <div>
                <button className="btn btn-success me-2" onClick={() => handleRsvp(Number(rsvp.eventId), 'available')}>Accept</button>
                <button className="btn btn-danger" onClick={() => handleRsvp(Number(rsvp.eventId), 'unavailable')}>Decline</button>
              </div>
            </li>
          ))}
        </ul>
      </div>
    </div>
  );
};

export default RsvpWidget;
