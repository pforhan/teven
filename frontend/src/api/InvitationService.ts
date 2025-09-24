import { apiClient } from './apiClient';

interface CreateInvitationResponse {
  invitationUrl: string;
}

interface InvitationResponse {
  invitationId: number;
  roleId: number;
  roleName: string;
  token: string;
  expiresAt: string;
  usedByUserId: number | null;
  createdAt: string;
}

export class InvitationService {
  static async createInvitation(organizationId: number, roleId: number): Promise<CreateInvitationResponse> {
    return apiClient<CreateInvitationResponse>(`/api/organizations/${organizationId}/invitations?roleId=${roleId}`, {
      method: 'POST',
    });
  }

  static async getUnusedInvitations(organizationId: number): Promise<InvitationResponse[]> {
    return apiClient<InvitationResponse[]>(`/api/organizations/${organizationId}/invitations`);
  }

  static async deleteInvitation(organizationId: number, invitationId: number): Promise<void> {
    return apiClient<void>(`/api/organizations/${organizationId}/invitations/${invitationId}`, {
      method: 'DELETE',
    });
  }
}
