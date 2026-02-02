import React, { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import { EventService } from '../../api/EventService';
import type { EventResponse } from '../../types/events';

interface OtherEventsPanelProps {
  date: string;
  organizationId: string | number;
  excludeEventId?: string | number;
}

const OtherEventsPanel: React.FC<OtherEventsPanelProps> = ({ date, organizationId, excludeEventId }) => {
  const [nearbyEvents, setNearbyEvents] = useState<EventResponse[]>([]);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    const fetchNearbyEvents = async () => {
      if (!date || !organizationId) {
        setNearbyEvents([]);
        return;
      }

      setLoading(true);
      try {
        const orgIdInt = typeof organizationId === 'string' ? parseInt(organizationId) : organizationId;
        if (isNaN(orgIdInt)) {
          setNearbyEvents([]);
          return;
        }

        const response = await EventService.getAllEvents(undefined, undefined, orgIdInt, date, date);
        let items = response.items;

        if (excludeEventId) {
          const excludeIdStr = excludeEventId.toString();
          items = items.filter(e => e.eventId.toString() !== excludeIdStr);
        }

        setNearbyEvents(items);
      } catch (err) {
        console.error("Failed to fetch nearby events", err);
      } finally {
        setLoading(false);
      }
    };

    fetchNearbyEvents();
  }, [date, organizationId, excludeEventId]);

  if (loading) {
    return (
      <div className="card border-0 bg-light shadow-sm mb-4">
        <div className="card-body p-4 text-center">
          <div className="spinner-border spinner-border-sm text-primary" role="status">
            <span className="visually-hidden">Loading...</span>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="card border-0 bg-light shadow-sm mb-4">
      <div className="card-body p-4">
        <h5 className="fw-bold mb-3 text-secondary">Other events on {date}</h5>
        {nearbyEvents.length === 0 ? (
          <p className="text-muted small mb-0">No other events scheduled for this day.</p>
        ) : (
          <div className="list-group list-group-flush bg-transparent">
            {[...nearbyEvents].sort((a, b) => a.time.localeCompare(b.time)).map(event => (
              <Link
                key={event.eventId}
                to={`/events/${event.eventId}`}
                className="list-group-item list-group-item-action bg-transparent px-0 py-3 border-bottom"
              >
                <div className="d-flex w-100 justify-content-between align-items-center">
                  <h6 className="mb-1 fw-bold text-dark">{event.title}</h6>
                  <small className="text-primary fw-bold">{event.time}</small>
                </div>
                <p className="mb-0 small text-muted">
                  <i className="bi bi-clock me-1"></i> {event.durationMinutes} min
                  {event.location && (
                    <span className="ms-3">
                      <i className="bi bi-geo-alt me-1"></i> {event.location}
                    </span>
                  )}
                </p>
              </Link>
            ))}
          </div>
        )}
      </div>
    </div>
  );
};

export default OtherEventsPanel;
