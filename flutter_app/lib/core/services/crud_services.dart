import '../../models/common.dart';
import '../../models/customer.dart';
import '../../models/inventory.dart';
import '../../models/organization.dart';
import '../../models/user.dart';
import '../api/api_client.dart';
import 'list_query.dart';

/// Decodes a paginated envelope whose items need [T.fromJson].
PaginatedResponse<T> _page<T>(
  Object? json,
  T Function(Map<String, dynamic>) fromJson,
) => PaginatedResponse.fromJson(
  json! as Map<String, dynamic>,
  (item) => fromJson(item! as Map<String, dynamic>),
);

/// Users, scoped to the caller's organization unless a super-admin passes an
/// explicit [ListQuery.organizationId].
///
/// Replaces the original user API service.
class UserService {
  const UserService(this._client);

  final ApiClient _client;

  Future<PaginatedResponse<UserResponse>> getAllUsers([
    ListQuery query = const ListQuery(),
  ]) => _client.get<PaginatedResponse<UserResponse>>(
    '/api/users',
    query: query.toParams(),
    decode: (json) => _page(json, UserResponse.fromJson),
  );

  Future<UserResponse> getUser(int userId) => _client.get<UserResponse>(
    '/api/users/$userId',
    decode: (json) => UserResponse.fromJson(json! as Map<String, dynamic>),
  );

  Future<UserResponse> createUser(CreateUserRequest request) =>
      _client.post<UserResponse>(
        '/api/users',
        request: request,
        decode: (json) => UserResponse.fromJson(json! as Map<String, dynamic>),
      );

  Future<UserResponse> updateUser(int userId, UpdateUserRequest request) =>
      _client.put<UserResponse>(
        '/api/users/$userId',
        request: request,
        decode: (json) => UserResponse.fromJson(json! as Map<String, dynamic>),
      );

  /// Deactivates (soft-deletes) a user.
  ///
  /// The server returns `204 No Content` on success.
  Future<void> deleteUser(int userId) => _client.delete('/api/users/$userId');

  Future<UserResponse> restoreUser(int userId) => _client.post<UserResponse>(
    '/api/users/$userId/restore',
    decode: (json) => UserResponse.fromJson(json! as Map<String, dynamic>),
  );
}

/// Organizations. Global-only endpoints — gated on
/// `VIEW_ORGANIZATIONS_GLOBAL` server-side.
class OrganizationService {
  const OrganizationService(this._client);

  final ApiClient _client;

  Future<PaginatedResponse<OrganizationResponse>> getAllOrganizations([
    ListQuery query = const ListQuery(),
  ]) => _client.get<PaginatedResponse<OrganizationResponse>>(
    '/api/organizations',
    query: query.toParams(),
    decode: (json) => _page(json, OrganizationResponse.fromJson),
  );

  Future<OrganizationResponse> getOrganization(int organizationId) =>
      _client.get<OrganizationResponse>(
        '/api/organizations/$organizationId',
        decode: (json) =>
            OrganizationResponse.fromJson(json! as Map<String, dynamic>),
      );

  Future<OrganizationResponse> createOrganization(
    CreateOrganizationRequest request,
  ) => _client.post<OrganizationResponse>(
    '/api/organizations',
    request: request,
    decode: (json) =>
        OrganizationResponse.fromJson(json! as Map<String, dynamic>),
  );

  Future<OrganizationResponse> updateOrganization(
    int organizationId,
    UpdateOrganizationRequest request,
  ) => _client.put<OrganizationResponse>(
    '/api/organizations/$organizationId',
    request: request,
    decode: (json) =>
        OrganizationResponse.fromJson(json! as Map<String, dynamic>),
  );

  /// Answers `204 NoContent`, so there is no payload to decode.
  Future<void> deleteOrganization(int organizationId) =>
      _client.delete('/api/organizations/$organizationId');
}

/// Customers.
class CustomerService {
  const CustomerService(this._client);

  final ApiClient _client;

  Future<PaginatedResponse<CustomerResponse>> getAllCustomers([
    ListQuery query = const ListQuery(),
  ]) => _client.get<PaginatedResponse<CustomerResponse>>(
    '/api/customers',
    query: query.toParams(),
    decode: (json) => _page(json, CustomerResponse.fromJson),
  );

  Future<CustomerResponse> getCustomer(int customerId) =>
      _client.get<CustomerResponse>(
        '/api/customers/$customerId',
        decode: (json) =>
            CustomerResponse.fromJson(json! as Map<String, dynamic>),
      );

  Future<CustomerResponse> createCustomer(CreateCustomerRequest request) =>
      _client.post<CustomerResponse>(
        '/api/customers',
        request: request,
        decode: (json) =>
            CustomerResponse.fromJson(json! as Map<String, dynamic>),
      );

  /// Returns the updated customer.
  Future<CustomerResponse> updateCustomer(
    int customerId,
    UpdateCustomerRequest request,
  ) => _client.put<CustomerResponse>(
    '/api/customers/$customerId',
    request: request,
    decode: (json) => CustomerResponse.fromJson(json! as Map<String, dynamic>),
  );

  /// Deactivates (soft-deletes) a customer.
  ///
  /// The server returns `204 No Content` on success.
  Future<void> deleteCustomer(int customerId) =>
      _client.delete('/api/customers/$customerId');

  Future<CustomerResponse> restoreCustomer(int customerId) =>
      _client.post<CustomerResponse>(
        '/api/customers/$customerId/restore',
        decode: (json) =>
            CustomerResponse.fromJson(json! as Map<String, dynamic>),
      );
}

/// Inventory items.
class InventoryService {
  const InventoryService(this._client);

  final ApiClient _client;

  Future<PaginatedResponse<InventoryItemResponse>> getAllInventoryItems([
    ListQuery query = const ListQuery(),
  ]) => _client.get<PaginatedResponse<InventoryItemResponse>>(
    '/api/inventory',
    query: query.toParams(),
    decode: (json) => _page(json, InventoryItemResponse.fromJson),
  );

  /// A single item, including **every** event that has used it.
  ///
  /// The `events` list is unpaginated — the server embeds all of them, with no
  /// way to page or filter. caps display client-side.
  Future<InventoryItemResponse> getInventoryItem(int inventoryId) =>
      _client.get<InventoryItemResponse>(
        '/api/inventory/$inventoryId',
        decode: (json) =>
            InventoryItemResponse.fromJson(json! as Map<String, dynamic>),
      );

  Future<InventoryItemResponse> createInventoryItem(
    CreateInventoryItemRequest request,
  ) => _client.post<InventoryItemResponse>(
    '/api/inventory',
    request: request,
    decode: (json) =>
        InventoryItemResponse.fromJson(json! as Map<String, dynamic>),
  );

  /// Returns the updated inventory item.
  Future<InventoryItemResponse> updateInventoryItem(
    int inventoryId,
    UpdateInventoryItemRequest request,
  ) => _client.put<InventoryItemResponse>(
    '/api/inventory/$inventoryId',
    request: request,
    decode: (json) =>
        InventoryItemResponse.fromJson(json! as Map<String, dynamic>),
  );

  /// Answers `204 NoContent`.
  Future<void> deleteInventoryItem(int inventoryId) =>
      _client.delete('/api/inventory/$inventoryId');

  /// Records usage against an event and returns the updated inventory item.
  Future<InventoryItemResponse> trackInventoryUsage(
    int inventoryId,
    TrackInventoryUsageRequest request,
  ) => _client.post<InventoryItemResponse>(
    '/api/inventory/$inventoryId/usage',
    request: request,
    decode: (json) =>
        InventoryItemResponse.fromJson(json! as Map<String, dynamic>),
  );
}
