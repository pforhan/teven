import type { CustomerResponse } from './customers';
import type { OrganizationResponse } from './organizations';

export interface StaffInviteDetails {
  specificStaffIds?: number[]; // Optional: list of specific staff to invite
  openInvitation: boolean; // True if invitation is open to any staff
  numberOfStaffNeeded: number; // Required: number of staff slots for the event
}

export interface EventInventoryItem {
  inventoryId: number;
  itemName: string;
  quantity: number;
}

export interface CreateEventRequest {
  title: string;
  date: string; // ISO 8601 date string (e.g., "YYYY-MM-DD")
  time: string; // ISO 8601 time string (e.g., "HH:MM:SS")
  durationMinutes: number;
  location?: string;
  description?: string;
  inventoryItems: EventInventoryItem[];
  customerId?: number; // Optional: Single customer ID
  staffInvites: StaffInviteDetails; // Details for staff invitation
  organizationId?: number;
}

export interface RsvpStatus {
  userId: number;
  displayName: string;
  email: string;
  availability: string; // "available" or "unavailable"
}

export interface EventResponse {
  eventId: number | string;
  title: string;
  date: string;
  time: string;
  durationMinutes: number;
  location?: string;
  description?: string;
  inventoryItems?: EventInventoryItem[];
  customer?: CustomerResponse;
  rsvps?: RsvpStatus[];
  organization?: OrganizationResponse;
  openInvitation?: boolean;
  numberOfStaffNeeded?: number;
  isPlaceholder?: boolean;
}

export interface UpdateEventRequest {
  title?: string;
  date?: string;
  time?: string;
  durationMinutes: number;
  location?: string;
  description?: string;
  inventoryItems?: EventInventoryItem[];
  customerId?: number;
  staffInvites?: StaffInviteDetails;
  organizationId?: number;
}

export interface RsvpRequest {
  availability: string; // "available" or "unavailable"
}

export interface VirtualEvent {
  id: string; // Unique ID for virtual event
  title: string;
  start: Date;
  end: Date;
  isVirtual: true;
}

export type CalendarEvent = (EventResponse | VirtualEvent) & { start: Date; end: Date; };