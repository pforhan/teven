import React, { useState, useCallback, useEffect } from 'react';
import { Calendar, momentLocalizer, Views } from 'react-big-calendar';
import type { View } from 'react-big-calendar';
import moment from 'moment';
import 'react-big-calendar/lib/css/react-big-calendar.css';
import { useNavigate } from 'react-router-dom';
import { EventService } from '../../api/EventService';
import type { EventResponse, CalendarEvent } from '../../types/events';
import { ApiErrorWithDetails } from '../../errors/ApiErrorWithDetails';

import { usePermissions } from '../../AuthContext';

const localizer = momentLocalizer(moment);

interface DateCellWrapperProps {
  children: React.ReactNode;
  value: Date;
  onSelectSlot: (slotInfo: any) => void;
  setPlaceholderEvent: (event: EventResponse | null) => void;
  view: View;
  leaveTimeoutRef: React.MutableRefObject<number | null>;
}

const DateCellWrapper = ({ children, value, onSelectSlot, setPlaceholderEvent, view, leaveTimeoutRef }: DateCellWrapperProps) => {

  const handleMouseEnter = () => {
    if (leaveTimeoutRef.current) {
      clearTimeout(leaveTimeoutRef.current);
      leaveTimeoutRef.current = null;
    }
    if (view === Views.MONTH) {
      const placeholder: EventResponse = {
        eventId: 'placeholder',
        title: 'Create Event',
        date: moment(value).format('YYYY-MM-DD'),
        time: '23:59',
        durationMinutes: 60,
        isPlaceholder: true,
      };
      setPlaceholderEvent(placeholder);
    }
  };

  const handleMouseLeave = () => {
    if (view === Views.MONTH) {
      leaveTimeoutRef.current = setTimeout(() => {
        setPlaceholderEvent(null);
      }, 100); // 100ms delay
    }
  };

  return (
    <div
      style={{ position: 'relative', height: '100%', width: '100%' }}
      onMouseEnter={handleMouseEnter}
      onMouseLeave={handleMouseLeave}
      onClick={() => onSelectSlot({ start: value, action: 'click' })}
    >
      <div
        className="rbc-day-bg"
        style={{ position: 'absolute', top: 0, left: 0, right: 0, bottom: 0 }}
      />
      {children}
    </div>
  );
};

const EventCalendar: React.FC = () => {
  const navigate = useNavigate();
  const { hasPermission } = usePermissions();
  const canManageEvents = hasPermission('MANAGE_EVENTS_ORGANIZATION');
  const [events, setEvents] = useState<EventResponse[]>([]);
  const [placeholderEvent, setPlaceholderEvent] = useState<EventResponse | null>(null);
  const [error, setError] = useState<{ message: string; details?: string } | null>(null);
  const [view, setView] = useState<View>(Views.MONTH);
  const [date, setDate] = useState(new Date());
  const leaveTimeoutRef = React.useRef<number | null>(null);

  const fetchEvents = useCallback(async (start: Date, end: Date) => {
    try {
      const eventData = await EventService.getAllEvents(1000, undefined, undefined, moment(start).format('YYYY-MM-DD'), moment(end).format('YYYY-MM-DD'));
      setEvents(eventData.items);
    } catch (err: unknown) {
      if (err instanceof ApiErrorWithDetails) {
        setError({ message: err.message, details: err.details });
      } else if (err instanceof Error) {
        setError({ message: err.message });
      } else {
        setError({ message: 'An unknown error occurred' });
      }
    }
  }, []);

  useEffect(() => {
    let start, end;
    switch (view) {
      case Views.WEEK:
      case Views.WORK_WEEK:
        start = moment(date).startOf('week').toDate();
        end = moment(date).endOf('week').toDate();
        break;
      case Views.DAY:
        start = moment(date).startOf('day').toDate();
        end = moment(date).endOf('day').toDate();
        break;
      case Views.AGENDA:
        start = moment(date).startOf('day').toDate();
        end = moment(date).add(1, 'month').endOf('day').toDate();
        break;
      case Views.MONTH:
      default:
        start = moment(date).startOf('month').toDate();
        end = moment(date).endOf('month').toDate();
        break;
    }
    fetchEvents(start, end);
  }, [fetchEvents, date, view]);

  const handleSelectSlot = ({ start, end, action }: { start: Date, end: Date, action: string }) => {
    if (action === 'select' || action === 'click') {
      const startTime = moment(start).format('HH:mm');
      const endTime = moment(end).format('HH:mm');
      const date = moment(start).format('YYYY-MM-DD');

      if (view === Views.MONTH) {
        if (action === 'click') {
          navigate(`/events/create?date=${date}`);
        }
      } else {
        navigate(`/events/create?date=${date}&startTime=${startTime}&endTime=${endTime}`);
      }
    }
  };

  const onSelectEvent = (event: CalendarEvent) => {
    if ('isPlaceholder' in event && event.isPlaceholder) {
      navigate(`/events/create?date=${moment(event.date).format('YYYY-MM-DD')}`);
      return;
    }
    if ('eventId' in event) {
      navigate(`/events/${event.eventId}`);
    }
  };

  const eventStyleGetter = (event: CalendarEvent) => {
    const isPlaceholder = 'isPlaceholder' in event && event.isPlaceholder;
    const style = {
      backgroundColor: isPlaceholder ? '#d3d3d3' : '#3174ad',
      borderRadius: '5px',
      opacity: 0.8,
      color: 'white',
      border: '0px',
      display: 'block',
    };
    return {
      style: style
    };
  };

  const dayPropGetter = (date: Date) => {
    const isToday = moment(date).isSame(new Date(), 'day');
    return {
      style: {
        backgroundColor: isToday ? '#e7f0f7' : '',
      },
    };
  };

  const EventComponent = ({ event, leaveTimeoutRef, setPlaceholderEvent }: { event: CalendarEvent; leaveTimeoutRef: React.MutableRefObject<number | null>; setPlaceholderEvent?: (event: EventResponse | null) => void; }) => {
    const handleMouseEnter = () => {
      if (leaveTimeoutRef.current) {
        clearTimeout(leaveTimeoutRef.current);
        leaveTimeoutRef.current = null;
      }
    };

    const handleMouseLeave = () => {
      if ('isPlaceholder' in event && event.isPlaceholder && setPlaceholderEvent) {
        leaveTimeoutRef.current = setTimeout(() => {
          setPlaceholderEvent(null);
        }, 100);
      }
    };

    if (view === Views.MONTH) {
      if ('isPlaceholder' in event && event.isPlaceholder) {
        return (
          <span onMouseEnter={handleMouseEnter} onMouseLeave={handleMouseLeave}>
            {event.title}
          </span>
        );
      }
      return <span>{event.title} {moment(event.start).format('h:mm A')}</span>;
    }
    return <span>{event.title}</span>;
  };

  const calendarEvents = [
    ...events.map((event: EventResponse) => ({
      ...event,
      start: new Date(event.date + 'T' + event.time),
      end: moment(event.date + 'T' + event.time).add(event.durationMinutes || 60, 'minutes').toDate(),
    })),
    ...(placeholderEvent ? [{
      ...placeholderEvent,
      start: new Date(placeholderEvent.date + 'T' + placeholderEvent.time),
      end: new Date(placeholderEvent.date + 'T' + placeholderEvent.time),
    }] : []),
  ];

  return (
    <div className="container-fluid">
      <div className="d-flex justify-content-between align-items-center mb-3">
        <h2>Event Calendar</h2>
        <div>
          <a href="/events/list" className="btn btn-primary">View All Events</a>
          {canManageEvents && (
            <button className="btn btn-primary ms-2" onClick={() => navigate('/events/create')}>Create Event</button>
          )}
        </div>
      </div>
      {error && (
        <div className="alert alert-danger">
          {error.message}
          {error.details && <pre>{error.details}</pre>}
        </div>
      )}
      <Calendar
        localizer={localizer}
        events={calendarEvents}
        startAccessor="start"
        endAccessor="end"
        style={{ height: 800 }}
        selectable
        onSelectSlot={handleSelectSlot}
        onSelectEvent={onSelectEvent}
        view={view}
        onView={view => setView(view)}
        date={date}
        onNavigate={date => setDate(date)}
        eventPropGetter={eventStyleGetter}
        dayPropGetter={dayPropGetter}
        components={{
          event: (props) => <EventComponent {...props} leaveTimeoutRef={leaveTimeoutRef} setPlaceholderEvent={setPlaceholderEvent} />,
          dateCellWrapper: (props) => {
            return (
              <DateCellWrapper {...props} onSelectSlot={handleSelectSlot} setPlaceholderEvent={setPlaceholderEvent} view={view} leaveTimeoutRef={leaveTimeoutRef} />
            );
          },
          month: {
            dateHeader: ({ date, label }: { date: Date, label: string }) => {
              const isToday = moment(date).isSame(new Date(), 'day');
              return (
                <div style={{ fontWeight: isToday ? 'bold' : 'normal' }}>
                  {label}
                </div>
              );
            },
          }
        }}
      />
    </div>
  );
};

export default EventCalendar;