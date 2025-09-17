export interface PaginatedResponse<T> {
  items: T[];
  total: number;
  offset: number;
  limit: number;
}

export interface StatusResponse {
  status: string;
  message: string;
}
