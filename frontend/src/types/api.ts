export interface ApiResponse<T> {
  success: boolean;
  data?: T;
  error?: ApiErrorResponse;
}

export interface ApiErrorResponse {
  message: string;
  details?: string;
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