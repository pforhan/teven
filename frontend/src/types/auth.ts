// frontend/src/types/auth.ts

export interface RegisterRequest {
  username: string;
  password: string;
  email: string;
  displayName: string;
  roles: string[];
}

export interface UserResponse {
  userId: number;
  username: string;
  email: string;
  displayName: string;
  roles: string[];
  organization: OrganizationDetails;
}

export interface LoginRequest {
  username: string;
  password: string;
}

export interface LoginResponse {
  token: string;
  user: UserResponse;
}

export interface StaffDetails {
  contactInformation: string;
  skills: string[];
  hoursWorked: number;
  phoneNumber: string;
  dateOfBirth: string; // ISO 8601 date string
}

export interface UserDetailsResponse {
  userId: number;
  username: string;
  email: string;
  displayName: string;
  roles: string[];
  staffDetails?: StaffDetails; // Nullable if user is not staff
}

export interface UpdateStaffDetails {
  contactInformation?: string;
  skills?: string[];
  phoneNumber?: string;
  dateOfBirth?: string; // ISO 8601 date string
}

export interface UpdateUserRequest {
  email?: string;
  displayName?: string;
  roles?: string[];
  staffDetails?: UpdateStaffDetails;
}

export interface CreateUserRequest {
  username: string;
  password: string;
  email: string;
  displayName: string;
  roles: string[];
  organizationId?: string;
}

export interface OrganizationDetails {
  organizationId: number;
  name: string;
  contactInformation: string;
  // TODO: Add other relevant organization details as needed
}

export interface UserContextResponse {
  user: UserResponse;
  permissions: string[]; // List of permissions for the user in current context
}
