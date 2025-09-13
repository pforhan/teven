import type { CreateEventRequest, EventResponse, UpdateEventRequest, RsvpRequest } from '../types/events';
import type { StatusResponse } from '../types/common';
import { apiClient } from './apiClient';

export class EventService {
  static async createEvent(request: CreateEventRequest): Promise<EventResponse> {
    return apiClient<EventResponse>('/api/events', {
      method: 'POST',
      body: JSON.stringify(request),
    });
  }

  static async getAllEvents(titleFilter?: string, sortByDate?: 'asc' | 'desc', organizationId?: number): Promise<EventResponse[]> {
    const url = new URL('/api/events', window.location.origin);
    if (titleFilter) {
      url.searchParams.append('title', titleFilter);
    }
    if (sortByDate) {
      url.searchParams.append('sortByDate', sortByDate);
    }
    if (organizationId) {
      url.searchParams.append('organizationId', organizationId.toString());
    }
    return apiClient<EventResponse[]>(url.toString());
  }

  static async getEvent(eventId: number): Promise<EventResponse> {
    return apiClient<EventResponse>(`/api/events/${eventId}`);
  }

  static async updateEvent(eventId: number, request: UpdateEventRequest): Promise<EventResponse> {
    return apiClient<EventResponse>(`/api/events/${eventId}`, {
      method: 'PUT',
      body: JSON.stringify(request),
    });
  }

  static async deleteEvent(eventId: number): Promise<StatusResponse> {
    return apiClient<StatusResponse>(`/api/events/${eventId}`, { method: 'DELETE' });
  }

  static async assignStaffToEvent(eventId: number, userId: number): Promise<StatusResponse> {
    return apiClient<StatusResponse>(`/api/events/${eventId}/staff/${userId}`, { method: 'POST' });
  }

  static async removeStaffFromEvent(eventId: number, userId: number): Promise<StatusResponse> {
    return apiClient<StatusResponse>(`/api/events/${eventId}/staff/${userId}`, { method: 'DELETE' });
  }

  static async rsvpToEvent(eventId: number, request: RsvpRequest): Promise<StatusResponse> {
    return apiClient<StatusResponse>(`/api/events/${eventId}/rsvp`, {
      method: 'POST',
      body: JSON.stringify(request),
    });
  }
}
