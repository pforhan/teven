import React, { useState, useEffect, useCallback } from 'react';
import { useNavigate } from 'react-router-dom';
import { EventService } from '../../api/EventService';
import type { EventResponse } from '../../types/events';
import { usePermissions } from '../../AuthContext';
import TableView, { type Column } from '../common/TableView';

const EventList: React.FC = () => {
  const navigate = useNavigate();
  const [events, setEvents] = useState<EventResponse[]>([]);
  const [error, setError] = useState<string | null>(null);
  const { hasPermission } = usePermissions();
  const canManageEvents = hasPermission('MANAGE_EVENTS_ORGANIZATION');
  const canViewGlobalEvents = hasPermission('VIEW_EVENTS_GLOBAL');
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

  const columns: Column<EventResponse>[] = [
    { key: 'title', label: 'Title' },
    { key: 'date', label: 'Date' },
    { key: 'time', label: 'Time' },
    { key: 'description', label: 'Description' },
    {
      key: 'inventoryItems',
      label: 'Inventory Items',
      render: (event: EventResponse) => (
        <ul>
          {event.inventoryItems.map(item => (
            <li key={item.inventoryId}>ID: {item.inventoryId} (Qty: {item.quantity})</li>
          ))}
        </ul>
      ),
    },
    ...(canViewGlobalEvents ? [{ key: 'organization' as keyof EventResponse, label: 'Organization', render: (event: EventResponse) => event.organization.name }] : []),
  ];

  const renderActions = (event: EventResponse) => (
    <>
      {canManageEvents && (
        <>
          <button className="btn btn-sm btn-primary me-2" onClick={() => navigate(`/events/edit/${event.eventId}`)}>Edit</button>
          <button className="btn btn-sm btn-danger" onClick={() => handleDelete(event.eventId)}>Delete</button>
        </>
      )}
    </>
  );

  return (
    <div className="container-fluid">
      <div className="d-flex justify-content-between align-items-center mb-3">
        <h2>Events</h2>
        {canManageEvents && (
          <button className="btn btn-primary" onClick={() => navigate('/events/create')}>Create Event</button>
        )}
      </div>

      <div className="row mb-3">
        <div className="col-md-6">
          <label htmlFor="titleFilter" className="form-label">Filter by Title:</label>
          <input
            type="text"
            id="titleFilter"
            className="form-control"
            value={titleFilter}
            onChange={(e) => setTitleFilter(e.target.value)}
          />
        </div>
        <div className="col-md-6">
          <label htmlFor="sortByDate" className="form-label">Sort by Date:</label>
          <select id="sortByDate" className="form-select" value={sortByDate} onChange={(e) => setSortByDate(e.target.value as 'asc' | 'desc' | '')}>
            <option value="">None</option>
            <option value="asc">Ascending</option>
            <option value="desc">Descending</option>
          </select>
        </div>
      </div>

      <TableView
        title=""
        data={events}
        columns={columns}
        getKey={(event) => event.eventId}
        renderActions={renderActions}
        error={error}
        canView={true} // Assuming anyone who can see the page can view the list
      />
    </div>
  );
};

export default EventList;
