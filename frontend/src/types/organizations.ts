// frontend/src/types/organizations.ts

export interface OrganizationResponse {
  organizationId: number;
  name: string;
  contactInformation: string;
}

export interface CreateOrganizationRequest {
  name: string;
  contactInformation: string;
}

export interface UpdateOrganizationRequest {
  name?: string;
  contactInformation?: string;
}
