import React, { useState, useEffect } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { EventService } from '../../api/EventService';
import type { EventResponse } from '../../types/events';
import ErrorDisplay from '../common/ErrorDisplay';
import { ApiErrorWithDetails } from '../../errors/ApiErrorWithDetails';
import { useAuth, usePermissions } from '../../AuthContext';
import OtherEventsPanel from './OtherEventsPanel';

const EventDetails: React.FC = () => {
  const { eventId } = useParams<{ eventId: string }>();
  const navigate = useNavigate();
  const [event, setEvent] = useState<EventResponse | null>(null);
  const [error, setError] = useState<{ message: string; details?: string } | null>(null);
  const [successMessage, setSuccessMessage] = useState<string | null>(null);
  const [myRsvpStatus, setMyRsvpStatus] = useState<string | null>(null);

  const { userContext } = useAuth();
  const { hasPermission } = usePermissions();
  const canJoinEvents = hasPermission('ASSIGN_TO_EVENTS_SELF');
  const canManageEvents = hasPermission('MANAGE_EVENTS_ORGANIZATION');

  useEffect(() => {
    const fetchEvent = async () => {
      if (!eventId) return;
      try {
        const fetchedEvent = await EventService.getEvent(parseInt(eventId));
        setEvent(fetchedEvent);
        const currentUserRsvp = fetchedEvent.rsvps?.find(rsvp => rsvp.userId === userContext?.user?.userId);
        setMyRsvpStatus(currentUserRsvp?.availability || null);
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
  }, [eventId, userContext?.user?.userId]);

  const handleDelete = async () => {
    if (!eventId) return;
    if (window.confirm('Are you sure you want to delete this event?')) {
      try {
        await EventService.deleteEvent(parseInt(eventId));
        navigate('/events');
      } catch (err: unknown) {
        if (err instanceof ApiErrorWithDetails) {
          setError({ message: err.message, details: err.details });
        } else {
          setError({ message: 'Failed to delete event' });
        }
      }
    }
  };

  const handleRsvpChange = async (availability: string) => {
    if (!eventId || !userContext?.user?.userId) return;
    setError(null);
    setSuccessMessage(null);

    try {
      await EventService.rsvpToEvent(parseInt(eventId), { availability });
      setSuccessMessage(`Successfully updated RSVP to ${availability}!`);
      setMyRsvpStatus(availability);
      const fetchedEvent = await EventService.getEvent(parseInt(eventId));
      setEvent(fetchedEvent);
    } catch (err: unknown) {
      if (err instanceof ApiErrorWithDetails) {
        setError({ message: err.message, details: err.details });
      } else {
        setError({ message: 'Failed to update RSVP' });
      }
    }
  };

  if (!event) {
    return (
      <div className="container mt-5 text-center">
        <div className="spinner-border text-primary" role="status">
          <span className="visually-hidden">Loading...</span>
        </div>
      </div>
    );
  }

  const yesRsvps = event.rsvps?.filter(r => r.availability === 'available') || [];
  const noRsvps = event.rsvps?.filter(r => r.availability === 'unavailable') || [];
  const requestedRsvps = event.rsvps?.filter(r => r.availability === 'requested') || [];

  return (
    <div className="container mt-4">
      <div className="d-flex justify-content-between align-items-center mb-4">
        <button className="btn btn-outline-secondary" onClick={() => navigate('/events')}>
          &larr; Back to Events
        </button>
        {canManageEvents && (
          <div className="btn-group">
            <button className="btn btn-outline-primary" onClick={() => navigate(`/events/edit/${eventId}`)}>Edit</button>
            <button className="btn btn-outline-danger" onClick={handleDelete}>Delete</button>
          </div>
        )}
      </div>

      <div className="row">
        <div className="col-lg-8">
          <div className="card shadow-sm mb-4">
            <div className="card-body p-4">
              <div className="mb-4">
                <h1 className="display-6 fw-bold">{event.title}</h1>
                <div className="d-flex gap-3 text-muted">
                  <span><i className="bi bi-calendar-event me-2"></i>{event.date}</span>
                  <span><i className="bi bi-clock me-2"></i>{event.time} ({event.durationMinutes} min)</span>
                  {event.location && (
                    <span>
                      <i className="bi bi-geo-alt me-2"></i>
                      <a
                        href={`https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(event.location)}`}
                        target="_blank"
                        rel="noopener noreferrer"
                        className="text-decoration-none text-primary"
                      >
                        {event.location}
                      </a>
                    </span>
                  )}
                </div>
              </div>

              <ErrorDisplay error={error} />
              {successMessage && <div className="alert alert-success">{successMessage}</div>}

              {event.description && (
                <div className="mb-4">
                  <h5 className="fw-bold">Notes / Description</h5>
                  <p className="text-dark" style={{ whiteSpace: 'pre-wrap' }}>{event.description}</p>
                </div>
              )}

              {event.customer && (
                <div className="mb-4 p-3 bg-light rounded shadow-sm border-start border-4 border-primary">
                  <h6 className="text-uppercase text-muted small fw-bold mb-2">Customer</h6>
                  <h5 className="mb-1">{event.customer.name}</h5>
                  {event.customer.phone && <div className="small text-muted mb-1"><i className="bi bi-phone me-2"></i>{event.customer.phone}</div>}
                  {event.customer.address && <div className="small text-muted"><i className="bi bi-house me-2"></i>{event.customer.address}</div>}
                </div>
              )}

              {event.inventoryItems && event.inventoryItems.length > 0 && (
                <div className="mb-4">
                  <h5 className="fw-bold mb-3">Inventory Required</h5>
                  <div className="row row-cols-1 row-cols-md-2 g-3">
                    {event.inventoryItems.map(item => (
                      <div key={item.inventoryId} className="col">
                        <div className="card h-100 border-0 bg-light p-2">
                          <div className="d-flex align-items-center">
                            <span className="badge bg-secondary rounded-pill me-3">{item.quantity}</span>
                            <span className="fw-bold">{item.itemName}</span>
                          </div>
                        </div>
                      </div>
                    ))}
                  </div>
                </div>
              )}
            </div>
          </div>
        </div>

        <div className="col-lg-4">
          {/* Other Events Panel */}
          {event && (
            <OtherEventsPanel
              date={event.date}
              organizationId={event.organization?.organizationId || ''}
              excludeEventId={eventId}
            />
          )}

          {/* RSVP Card */}
          <div className="card shadow-sm mb-4">
            <div className="card-body p-4">
              <h5 className="fw-bold mb-3">Your Availability</h5>
              {canJoinEvents ? (
                <div className="btn-group w-100 mb-3" role="group">
                  <button
                    className={`btn py-2 ${myRsvpStatus === 'available' ? 'btn-success shadow-sm' : 'btn-outline-success'}`}
                    onClick={() => handleRsvpChange('available')}
                  >
                    <i className="bi bi-check-circle me-1"></i> Going
                  </button>
                  <button
                    className={`btn py-2 ${myRsvpStatus === 'unavailable' ? 'btn-danger shadow-sm' : 'btn-outline-danger'}`}
                    onClick={() => handleRsvpChange('unavailable')}
                  >
                    <i className="bi bi-x-circle me-1"></i> Not Going
                  </button>
                </div>
              ) : (
                <p className="text-muted small">You don't have permission to RSVP to this event.</p>
              )}
              {myRsvpStatus && (
                <button
                  className="btn btn-link btn-sm text-decoration-none w-100"
                  onClick={() => handleRsvpChange('no response')}
                >
                  Clear my response
                </button>
              )}
            </div>
          </div>

          {/* Roster Card */}
          <div className="card shadow-sm">
            <div className="card-body p-4">
              <h5 className="fw-bold mb-3 d-flex justify-content-between align-items-center">
                Staff Roster
                <span className="badge bg-primary rounded-pill small">{yesRsvps.length}</span>
              </h5>

              <div className="mb-4">
                <h6 className="text-primary small fw-bold text-uppercase mb-2">Invited</h6>
                {requestedRsvps.length > 0 ? (
                  <ul className="list-group list-group-flush small">
                    {requestedRsvps.map(user => (
                      <li key={user.userId} className="list-group-item px-0 border-0 py-1 text-muted">
                        <i className="bi bi-envelope me-2"></i>
                        {user.displayName || user.email}
                      </li>
                    ))}
                  </ul>
                ) : (
                  <p className="text-muted small ms-4">No pending invitations.</p>
                )}
              </div>

              <div className="mb-4">
                <h6 className="text-success small fw-bold text-uppercase mb-2">Confirmed</h6>
                {yesRsvps.length > 0 ? (
                  <ul className="list-group list-group-flush small">
                    {yesRsvps.map(user => (
                      <li key={user.userId} className="list-group-item px-0 border-0 py-1">
                        <i className="bi bi-person-check-fill text-success me-2"></i>
                        {user.displayName || user.email}
                      </li>
                    ))}
                  </ul>
                ) : (
                  <p className="text-muted small ms-4">No one confirmed yet.</p>
                )}
              </div>

              {canManageEvents && noRsvps.length > 0 && (
                <div>
                  <h6 className="text-danger small fw-bold text-uppercase mb-2">Declined</h6>
                  <ul className="list-group list-group-flush small">
                    {noRsvps.map(user => (
                      <li key={user.userId} className="list-group-item px-0 border-0 py-1 text-muted">
                        <i className="bi bi-person-x me-2 text-danger"></i>
                        {user.displayName || user.email}
                      </li>
                    ))}
                  </ul>
                </div>
              )}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

export default EventDetails;
