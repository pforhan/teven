import React, { useState, useEffect, useCallback } from 'react';
import { useNavigate } from 'react-router-dom';
import { EventService } from '../../api/EventService';
import type { EventResponse } from '../../types/events';
import { usePermissions } from '../../AuthContext';
import ErrorDisplay from '../common/ErrorDisplay';

const EventList: React.FC = () => {
  const navigate = useNavigate();
  const [events, setEvents] = useState<EventResponse[]>([]);
  const [error, setError] = useState<string | null>(null);
  const { hasPermission } = usePermissions();
  const [titleFilter, setTitleFilter] = useState('');
  const [sortByDate, setSortByDate] = useState<'asc' | 'desc' | ''>('');

  const fetchEvents = useCallback(async () => {
    try {
      const eventData = await EventService.getAllEvents(titleFilter, sortByDate === '' ? undefined : sortByDate);
      setEvents(eventData);
    } catch (err) {
      if (err instanceof Error) {
        setError(err.message);
      } else {
        setError('An unknown error occurred');
      }
    }
  }, [titleFilter, sortByDate]);

  useEffect(() => {
    fetchEvents();
  }, [fetchEvents]);

  const handleDelete = async (eventId: number) => {
    if (window.confirm('Are you sure you want to delete this event?')) {
      try {
        await EventService.deleteEvent(eventId);
        fetchEvents(); // Re-fetch events after deletion
      } catch (err) {
        if (err instanceof Error) {
          setError(err.message);
        } else {
          setError('An unknown error occurred');
        }
      }
    }
  };

  return (
    <div>
      <h2>Events</h2>
      <ErrorDisplay message={error} />

      <div>
        <label htmlFor="titleFilter">Filter by Title:</label>
        <input
          type="text"
          id="titleFilter"
          value={titleFilter}
          onChange={(e) => setTitleFilter(e.target.value)}
        />
      </div>
      <div>
        <label htmlFor="sortByDate">Sort by Date:</label>
        <select id="sortByDate" value={sortByDate} onChange={(e) => setSortByDate(e.target.value as 'asc' | 'desc' | '')}>
          <option value="">None</option>
          <option value="asc">Ascending</option>
          <option value="desc">Descending</option>
        </select>
      </div>

      {hasPermission('MANAGE_EVENTS_ORGANIZATION') && (
        <button onClick={() => navigate('/events/create')}>Create Event</button>
      )}
      <ul>
        {events.map(event => (
          <li key={event.eventId}>
            <strong>{event.title}</strong> - {event.date} at {event.time}
            {hasPermission('MANAGE_EVENTS_ORGANIZATION') && (
              <>
                <button onClick={() => navigate(`/events/edit/${event.eventId}`)}>Edit</button>
                <button onClick={() => handleDelete(event.eventId)}>Delete</button>
              </>
            )}
          </li>
        ))}
      </ul>
    </div>
  );
};

export default EventList;
