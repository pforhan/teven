// frontend/src/api/EventService.ts

import type { CreateEventRequest, EventResponse, UpdateEventRequest, RsvpRequest } from '../types/events';
import type { StatusResponse } from '../types/common';
import { AuthService } from './AuthService';

export class EventService {
  static async createEvent(request: CreateEventRequest): Promise<EventResponse> {
    const response = await fetch('/api/events', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        ...AuthService.getAuthHeader(),
      },
      body: JSON.stringify(request),
    });
    if (!response.ok) {
      const errorData = await response.json();
      throw new Error(errorData.message || 'Failed to create event');
    }
    return response.json();
  }

  static async getAllEvents(titleFilter?: string, sortByDate?: 'asc' | 'desc'): Promise<EventResponse[]> {
    const url = new URL('/api/events', window.location.origin);
    if (titleFilter) {
      url.searchParams.append('title', titleFilter);
    }
    if (sortByDate) {
      url.searchParams.append('sortByDate', sortByDate);
    }

    const response = await fetch(url.toString(), {
      method: 'GET',
      headers: AuthService.getAuthHeader(),
    });
    if (!response.ok) {
      const errorData = await response.json();
      throw new Error(errorData.message || 'Failed to fetch events');
    }
    return response.json();
  }

  static async getEvent(eventId: number): Promise<EventResponse> {
    const response = await fetch(`/api/events/${eventId}`, {
      method: 'GET',
      headers: AuthService.getAuthHeader(),
    });
    if (!response.ok) {
      const errorData = await response.json();
      throw new Error(errorData.message || 'Failed to fetch event');
    }
    return response.json();
  }

  static async updateEvent(eventId: number, request: UpdateEventRequest): Promise<EventResponse> {
    const response = await fetch(`/api/events/${eventId}`, {
      method: 'PUT',
      headers: {
        'Content-Type': 'application/json',
        ...AuthService.getAuthHeader(),
      },
      body: JSON.stringify(request),
    });
    if (!response.ok) {
      const errorData = await response.json();
      throw new Error(errorData.message || 'Failed to update event');
    }
    return response.json();
  }

  static async deleteEvent(eventId: number): Promise<StatusResponse> {
    const response = await fetch(`/api/events/${eventId}`, {
      method: 'DELETE',
      headers: AuthService.getAuthHeader(),
    });
    if (!response.ok) {
      const errorData = await response.json();
      throw new Error(errorData.message || 'Failed to delete event');
    }
    return response.json();
  }

  static async assignStaffToEvent(eventId: number, userId: number): Promise<StatusResponse> {
    const response = await fetch(`/api/events/${eventId}/staff/${userId}`, {
      method: 'POST',
      headers: AuthService.getAuthHeader(),
    });
    if (!response.ok) {
      const errorData = await response.json();
      throw new Error(errorData.message || 'Failed to assign staff');
    }
    return response.json();
  }

  static async removeStaffFromEvent(eventId: number, userId: number): Promise<StatusResponse> {
    const response = await fetch(`/api/events/${eventId}/staff/${userId}`, {
      method: 'DELETE',
      headers: AuthService.getAuthHeader(),
    });
    if (!response.ok) {
      const errorData = await response.json();
      throw new Error(errorData.message || 'Failed to remove staff');
    }
    return response.json();
  }

  static async rsvpToEvent(eventId: number, request: RsvpRequest): Promise<StatusResponse> {
    const response = await fetch(`/api/events/${eventId}/rsvp`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        ...AuthService.getAuthHeader(),
      },
      body: JSON.stringify(request),
    });
    if (!response.ok) {
      const errorData = await response.json();
      throw new Error(errorData.message || 'Failed to RSVP to event');
    }
    return response.json();
  }
}
