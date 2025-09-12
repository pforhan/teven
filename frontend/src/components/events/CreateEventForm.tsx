import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { EventService } from '../../api/EventService';
import type { CreateEventRequest, EventInventoryItem } from '../../types/events';
import ErrorDisplay from '../common/ErrorDisplay';
import InventoryAssociationEditor from '../common/InventoryAssociationEditor';

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
        inventoryIds: inventoryItems.map((item) => item.inventoryId),
        customerId: parseInt(customerId),
        staffInvites: {
          openInvitation,
          numberOfStaffNeeded,
        },
      };

      await EventService.createEvent(request);
      navigate('/events');
    } catch (err) {
      if (err instanceof Error) {
        setError(err.message);
      } else {
        setError('An unknown error occurred');
      }
    }
  };

  return (
    <div className="card">
      <div className="card-body">
        <h2 className="card-title">Create New Event</h2>
        <ErrorDisplay message={error} />
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
