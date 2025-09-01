// frontend/src/types/customers.ts

export interface CustomerResponse {
  customerId: number;
  name: string;
  phone: string;
  address: string;
  notes: string;
}

export interface CreateCustomerRequest {
  name: string;
  phone: string;
  address: string;
  notes: string;
}

export interface UpdateCustomerRequest {
  name?: string;
  phone?: string;
  address?: string;
  notes?: string;
}
