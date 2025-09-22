import type { CreateEventRequest, EventResponse, UpdateEventRequest, RsvpRequest } from '../types/events';
import type { StatusResponse, PaginatedResponse } from '../types/common';
import { apiClient } from './apiClient';

export class EventService {
  static async createEvent(request: CreateEventRequest): Promise<EventResponse> {
    return apiClient<EventResponse>('/api/events', {
      method: 'POST',
      body: JSON.stringify(request),
    });
  }

  static async getAllEvents(limit?: number, offset?: number, organizationId?: number, startDate?: String, endDate?: String, sortOrder?: string): Promise<PaginatedResponse<EventResponse>> {
    const url = new URL('/api/events', window.location.origin);
    if (limit) {
      url.searchParams.append('limit', limit.toString());
    }
    if (offset) {
      url.searchParams.append('offset', offset.toString());
    }
    if (organizationId) {
      url.searchParams.append('organizationId', organizationId.toString());
    }
    if (startDate) {
      url.searchParams.append('startDate', startDate.toString());
    }
    if (endDate) {
      url.searchParams.append('endDate', endDate.toString());
    }
    if (sortOrder) {
      url.searchParams.append('sortOrder', sortOrder);
    }
    return apiClient<PaginatedResponse<EventResponse>>(url.toString());
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

  static async rsvpToEvent(eventId: number, request: RsvpRequest): Promise<StatusResponse> {
    return apiClient<StatusResponse>(`/api/events/${eventId}/rsvp`, {
      method: 'POST',
      body: JSON.stringify(request),
    });
  }

  static async joinEvent(eventId: number): Promise<StatusResponse> {
    return apiClient<StatusResponse>(`/api/events/${eventId}/join`, { method: 'POST' });
  }

  static async getRequestedRsvps(): Promise<EventResponse[]> {
    return apiClient<EventResponse[]>('/api/events/rsvps/requested');
  }
}
