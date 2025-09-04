import React, { useState, useEffect } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { EventService } from '../../api/EventService';
import type { EventResponse, UpdateEventRequest, EventInventoryItem } from '../../types/events';
import ErrorDisplay from '../common/ErrorDisplay';
import InventoryAssociationEditor from '../common/InventoryAssociationEditor';

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
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const fetchEvent = async () => {
      if (!eventId) return;
      try {
        const fetchedEvent = await EventService.getEvent(parseInt(eventId));
        setEvent(fetchedEvent);
        setTitle(fetchedEvent.title);
        setDate(fetchedEvent.date);
        setTime(fetchedEvent.time);
        setLocation(fetchedEvent.location);
        setDescription(fetchedEvent.description);
        setInventoryItems(fetchedEvent.inventoryItems);
        setCustomerId(fetchedEvent.customerId.toString());
        setOpenInvitation(false);
        setNumberOfStaffNeeded(0);
      } catch (err) {
        if (err instanceof Error) {
          setError(err.message);
        } else {
          setError('An unknown error occurred');
        }
      }
    };
    fetchEvent();
  }, [eventId]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);

    if (!eventId) return;

    try {
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
      };

      await EventService.updateEvent(parseInt(eventId), request);
      navigate('/events');
    } catch (err) {
      if (err instanceof Error) {
        setError(err.message);
      } else {
        setError('An unknown error occurred');
      }
    }
  };

  if (!event) {
    return <div>Loading event...</div>;
  }

  return (
    <div>
      <h2>Edit Event: {event.title}</h2>
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
          <InventoryAssociationEditor
            initialInventoryItems={event.inventoryItems}
            onInventoryItemsChange={setInventoryItems}
          />
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
        <button type="submit">Update Event</button>
        <button type="button" onClick={() => navigate('/events')}>Cancel</button>
      </form>
    </div>
  );
};

export default EditEventForm;
