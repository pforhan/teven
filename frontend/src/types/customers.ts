// frontend/src/types/customers.ts

import type { OrganizationResponse } from './organizations';

export interface CustomerResponse {
  customerId: number;
  name: string;
  phone: string;
  address: string;
  notes: string;
  organization: OrganizationResponse;
}

export interface CreateCustomerRequest {
  name: string;
  phone: string;
  address: string;
  notes: string;
  organizationId?: number;
}

export interface UpdateCustomerRequest {
  name?: string;
  phone?: string;
  address?: string;
  notes?: string;
  organizationId?: number;
}
