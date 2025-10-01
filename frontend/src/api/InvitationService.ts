import { apiClient } from './apiClient';
import type { InvitationResponse, ValidateInvitationResponse } from '../types/api';

interface AcceptInvitationRequest {
  token: string;
  username: string;
  password: string;
  email: string;
  displayName: string;
}

interface AcceptInvitationResponse {
  success: boolean;
  message?: string;
}

export class InvitationService {
  static async createInvitation(roleId: number, organizationId?: number, note?: string): Promise<InvitationResponse> {
    return apiClient<InvitationResponse>('/api/invitations', {
      method: 'POST',
      body: JSON.stringify({ roleId, organizationId, note }),
    });
  }

  static async getUnusedInvitations(): Promise<InvitationResponse[]> {
    return apiClient<InvitationResponse[]>('/api/invitations');
  }

  static async deleteInvitation(invitationId: number): Promise<void> {
    return apiClient<void>(`/api/invitations/${invitationId}`, {
      method: 'DELETE',
    });
  }

  static async validateInvitation(token: string): Promise<ValidateInvitationResponse> {
    return apiClient<ValidateInvitationResponse>(`/api/invitations/validate?token=${token}`);
  }

  static async acceptInvitation(request: AcceptInvitationRequest): Promise<AcceptInvitationResponse> {
    return apiClient<AcceptInvitationResponse>('/api/invitations/accept', {
      method: 'POST',
      body: JSON.stringify(request),
    });
  }
}
