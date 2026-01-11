import { AuthService } from './AuthService';
import { UnauthorizedError } from '../errors/UnauthorizedError';
import { ApiErrorWithDetails } from '../errors/ApiErrorWithDetails';
import type { ApiResponse } from '../types/api';

export const apiClient = async <T>(url: string, options: RequestInit = {}): Promise<T> => {
  const headers = {
    ...options.headers,
    ...AuthService.getAuthHeader(),
    'Content-Type': 'application/json',
  };

  const response = await fetch(url, { ...options, headers });

  // We expect all valid API responses to be JSON, even if the success status is not ok.

  if (!response.ok) {
    const contentType = response.headers.get("content-type");
    if (contentType && contentType.indexOf("application/json") !== -1) {
      const apiResponse: ApiResponse<T> = await response.json();
      if (apiResponse.error) {
        if (response.status === 401) {
          throw new UnauthorizedError(apiResponse.error.message);
        }
        throw new ApiErrorWithDetails(apiResponse.error.message, apiResponse.error.details);
      } else {
        throw new ApiErrorWithDetails(
          `API request failed with status ${response.status}`,
          `Unknown error from API: ${JSON.stringify(apiResponse)}`
        );
      }
    } else {
      const errorText = await response.text();
      if (response.status === 401) {
        throw new UnauthorizedError('Session expired. Please log in again.');
      }
      throw new ApiErrorWithDetails(
        `API request failed with status ${response.status}`,
        errorText
      );
    }
  }

  const contentType = response.headers.get("content-type");
  if (contentType && contentType.indexOf("application/json") !== -1) {
    const apiResponse: ApiResponse<T> = await response.json();
    if (apiResponse.success) {
      return apiResponse.data as T;
    } else {
      throw new ApiErrorWithDetails(apiResponse.error?.message || 'API request failed', apiResponse.error?.details);
    }
  } else {
    // If there's no content, we can't reasonably return a T, so we'll return null
    return null as T;
  }
};