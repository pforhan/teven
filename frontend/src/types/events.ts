// frontend/src/types/events.ts

export interface StaffInviteDetails {
  specificStaffIds?: number[]; // Optional: list of specific staff to invite
  openInvitation: boolean; // True if invitation is open to any staff
  numberOfStaffNeeded: number; // Required: number of staff slots for the event
}

export interface EventInventoryItem {
  inventoryId: number;
  quantity: number;
}

export interface CreateEventRequest {
  title: string;
  date: string; // ISO 8601 date string (e.g., "YYYY-MM-DD")
  time: string; // ISO 8601 time string (e.g., "HH:MM:SS")
  location: string;
  description: string;
  inventoryItems: EventInventoryItem[];
  customerId: number; // Single customer ID
  staffInvites: StaffInviteDetails; // Details for staff invitation
}

export interface RsvpStatus {
  userId: number;
  availability: string; // "available" or "unavailable"
}

export interface EventResponse {
  eventId: number;
  title: string;
  date: string;
  time: string;
  location: string;
  description: string;
  inventoryItems: EventInventoryItem[];
  customerId: number;
  assignedStaffIds: number[];
  rsvps: RsvpStatus[];
}

export interface UpdateEventRequest {
  title?: string;
  date?: string;
  time?: string;
  location?: string;
  description?: string;
  inventoryItems?: EventInventoryItem[];
  customerId?: number;
  staffInvites?: StaffInviteDetails;
}

export interface RsvpRequest {
  availability: string; // "available" or "unavailable"
}