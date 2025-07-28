// frontend/src/components/events/CreateEventForm.tsx

import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { EventService } from '../../api/EventService';
import type { CreateEventRequest } from '../../types/events';
import ErrorDisplay from '../common/ErrorDisplay';

const CreateEventForm: React.FC = () => {
  const navigate = useNavigate();
  const [title, setTitle] = useState('');
  const [date, setDate] = useState('');
  const [time, setTime] = useState('');
  const [location, setLocation] = useState('');
  const [description, setDescription] = useState('');
  const [inventoryIds, setInventoryIds] = useState(''); // TODO: Implement proper multi-select
  const [customerId, setCustomerId] = useState(''); // TODO: Implement proper customer selection
  const [openInvitation, setOpenInvitation] = useState(false);
  const [numberOfStaffNeeded, setNumberOfStaffNeeded] = useState(0);
  const [error, setError] = useState<string | null>(null);

  const handleSubmit = async (event: React.FormEvent) => {
    event.preventDefault();
    setError(null);

    try {
      const request: CreateEventRequest = {
        title,
        date,
        time,
        location,
        description,
        inventoryIds: inventoryIds.split(',').map(id => parseInt(id.trim())).filter(id => !isNaN(id)),
        customerId: parseInt(customerId),
        staffInvites: {
          openInvitation,
          numberOfStaffNeeded,
          // specificStaffIds: [], // TODO: Implement specific staff selection
        },
      };

      await EventService.createEvent(request);
      navigate('/events'); // Redirect to event list after creation
    } catch (err) {
      if (err instanceof Error) {
        setError(err.message);
      } else {
        setError('An unknown error occurred');
      }
    }
  };

  return (
    <div>
      <h2>Create New Event</h2>
      <ErrorDisplay message={error} />
      <form onSubmit={handleSubmit}>
        <div>
          <label htmlFor="title">Title:</label>
          <input type="text" id="title" value={title} onChange={(e) => setTitle(e.target.value)} required />
        </div>
        <div>
          <label htmlFor="date">Date:</label>
          <input type="date" id="date" value={date} onChange={(e) => setDate(e.target.value)} required />
        </div>
        <div>
          <label htmlFor="time">Time:</label>
          <input type="time" id="time" value={time} onChange={(e) => setTime(e.target.value)} required />
        </div>
        <div>
          <label htmlFor="location">Location:</label>
          <input type="text" id="location" value={location} onChange={(e) => setLocation(e.target.value)} required />
        </div>
        <div>
          <label htmlFor="description">Description:</label>
          <textarea id="description" value={description} onChange={(e) => setDescription(e.target.value)} required />
        </div>
        <div>
          <label htmlFor="inventoryIds">Inventory IDs (comma-separated):</label>
          <input type="text" id="inventoryIds" value={inventoryIds} onChange={(e) => setInventoryIds(e.target.value)} />
        </div>
        <div>
          <label htmlFor="customerId">Customer ID:</label>
          <input type="number" id="customerId" value={customerId} onChange={(e) => setCustomerId(e.target.value)} required />
        </div>
        <div>
          <label htmlFor="openInvitation">Open Invitation:</label>
          <input type="checkbox" id="openInvitation" checked={openInvitation} onChange={(e) => setOpenInvitation(e.target.checked)} />
        </div>
        <div>
          <label htmlFor="numberOfStaffNeeded">Number of Staff Needed:</label>
          <input type="number" id="numberOfStaffNeeded" value={numberOfStaffNeeded} onChange={(e) => setNumberOfStaffNeeded(parseInt(e.target.value))} required />
        </div>
        <button type="submit">Create Event</button>
        <button type="button" onClick={() => navigate('/events')}>Cancel</button>
      </form>
    </div>
  );
};

export default CreateEventForm;
