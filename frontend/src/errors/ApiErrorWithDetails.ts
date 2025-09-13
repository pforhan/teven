export class ApiErrorWithDetails extends Error {
  details?: string;

  constructor(message: string, details?: string) {
    super(message);
    this.name = 'ApiErrorWithDetails';
    this.details = details;
  }
}
