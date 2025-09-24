import { apiClient } from './apiClient';
import type { InvitationResponse } from '../types/api';

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
}
