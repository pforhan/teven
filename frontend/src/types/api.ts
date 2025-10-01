export interface ApiResponse<T> {
  success: boolean;
  data?: T;
  error?: ApiErrorResponse;
}

export interface ApiErrorResponse {
  message: string;
  details?: string;
}

export interface ValidateInvitationResponse {
  organizationId: number;
  organizationName: string;
  roleName: string;
}

export interface InvitationResponse {
  invitationId: number;
  organizationId: number;
  roleId: number;
  roleName: string;
  token: string;
  expiresAt: string;
  usedByUserId: number | null;
  createdAt: string;
  note: string | null;
}