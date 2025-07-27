// frontend/src/types/customers.ts

export interface CustomerResponse {
  customerId: number;
  name: string;
  contactInformation: string;
}

export interface CreateCustomerRequest {
  name: string;
  contactInformation: string;
}

export interface UpdateCustomerRequest {
  name?: string;
  contactInformation?: string;
}
