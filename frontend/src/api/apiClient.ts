import { AuthService } from './AuthService';
import { UnauthorizedError } from '../errors/UnauthorizedError';

export const apiClient = async (url: string, options: RequestInit = {}) => {
  const headers = {
    ...options.headers,
    ...AuthService.getAuthHeader(),
    'Content-Type': 'application/json',
  };

  const response = await fetch(url, { ...options, headers });

  if (response.status === 401) {
    throw new UnauthorizedError('Session expired. Please log in again.');
  }

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(
      `API request failed with status ${response.status}: ${errorText}`
    );
  }

  // If response has no content, return null, otherwise return json
  const contentType = response.headers.get("content-type");
  if (contentType && contentType.indexOf("application/json") !== -1) {
    return response.json();
  } else {
    return null;
  }
};