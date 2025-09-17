import React, { useState, useCallback, useEffect } from 'react';
import { Calendar, momentLocalizer, Views } from 'react-big-calendar';
import type { View } from 'react-big-calendar';
import moment from 'moment';
import 'react-big-calendar/lib/css/react-big-calendar.css';
import { useNavigate } from 'react-router-dom';
import { EventService } from '../../api/EventService';
import type { EventResponse } from '../../types/events';
import { ApiErrorWithDetails } from '../../errors/ApiErrorWithDetails';

const localizer = momentLocalizer(moment);

const DateCellWrapper = ({ children, value, onSelectSlot }: { children: React.ReactNode, value: Date, onSelectSlot: (slotInfo: any) => void }) => {
  const navigate = useNavigate();
  const [isHovered, setIsHovered] = useState(false);

  return (
    <div
      className="rbc-day-bg"
      onMouseEnter={() => setIsHovered(true)}
      onMouseLeave={() => setIsHovered(false)}
      onClick={() => onSelectSlot({ start: value, action: 'click' })}
    >
      {children}
      {isHovered && (
        <button
          className="btn btn-primary btn-sm"
          style={{ position: 'absolute', top: '5px', right: '5px' }}
          onClick={(e) => {
            e.stopPropagation();
            navigate(`/events/create?date=${moment(value).format('YYYY-MM-DD')}`)
          }}
        >
          +
        </button>
      )}
    </div>
  );
};

const EventCalendar: React.FC = () => {
  const navigate = useNavigate();
  const [events, setEvents] = useState<EventResponse[]>([]);
  const [error, setError] = useState<{ message: string; details?: string } | null>(null);
  const [view, setView] = useState<View>(Views.MONTH);
  const [date, setDate] = useState(new Date());

  const fetchEvents = useCallback(async (start: Date, end: Date) => {
    try {
      const eventData = await EventService.getAllEvents(undefined, undefined, undefined, moment(start).format('YYYY-MM-DD'), moment(end).format('YYYY-MM-DD'));
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
      case Views.DAY:
      case Views.AGENDA:
        start = moment(date).startOf('week').toDate();
        end = moment(date).endOf('week').toDate();
        break;
      case Views.MONTH:
      default:
        start = moment(date).startOf('month').toDate();
        end = moment(date).endOf('month').toDate();
        break;
    }
    fetchEvents(start, end);
  }, [fetchEvents, date, view]);

  const handleSelectSlot = ({ start, action }: { start: Date, action: string }) => {
    if (view === Views.WEEK && action === 'click') {
      navigate(`/events/create?date=${moment(start).format('YYYY-MM-DD')}&time=${moment(start).format('HH:mm')}`);
    } else if (view === Views.MONTH && action === 'click') {
      navigate(`/events/create?date=${moment(start).format('YYYY-MM-DD')}`);
    }
  };

  

  const eventStyleGetter = () => {
    const style = {
      backgroundColor: '#3174ad',
      borderRadius: '5px',
      opacity: 0.8,
      color: 'white',
      border: '0px',
      display: 'block'
    };
    return {
      style: style
    };
  };

  const EventComponent = ({ event }: { event: EventResponse }) => {
    if (view === Views.MONTH) {
      return <span>{event.title} {event.time}</span>;
    }
    return <span>{event.title}</span>;
  };

  const calendarEvents = events.map((event: EventResponse) => ({
    ...event,
    start: new Date(event.date + 'T' + event.time),
    end: new Date(event.date + 'T' + event.time),
  }));

  return (
    <div className="container-fluid">
      <div className="d-flex justify-content-between align-items-center mb-3">
        <h2>Event Calendar</h2>
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
        view={view}
        onView={view => setView(view)}
        date={date}
        onNavigate={date => setDate(date)}
        eventPropGetter={eventStyleGetter}
        components={{
          event: EventComponent,
          dateCellWrapper: (props) => <DateCellWrapper {...props} onSelectSlot={handleSelectSlot} />,
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