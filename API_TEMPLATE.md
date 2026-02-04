## Teven Service APIs

This document outlines the API endpoints for the Teven service, including their purpose, authentication requirements, and the expected request/response data structures. Data structures are presented using Kotlin pseudocode for conciseness.

### Base API Response

All API responses will follow a consistent structure to ensure predictable handling of successes and failures.

<!-- DATA_MODEL_ApiResponse -->

<!-- DATA_MODEL_ApiError -->

<!-- DATA_MODEL_PaginatedResponse -->

*   `success`: A boolean indicating if the request was successful.
*   `data`: The payload of the response. For successful requests, this will contain the requested data. For failed requests, this will be `null`.
*   `error`: An object containing error details. For successful requests, this will be `null`.
*   `PaginatedResponse`: A standard structure for paginated lists of data.

---

### Common Search, Sort, and Pagination Parameters

Many `GET` list endpoints support the following optional query parameters:

*   `limit` (optional, integer): The maximum number of items to return. Defaults to 10 or 1000 depending on the endpoint.
*   `offset` (optional, integer): The number of items to skip. Defaults to 0.
*   `search` (optional, string): A search filter applied to relevant fields (e.g., name, title, description).
*   `sortBy` (optional, string): The field to sort by. Supported fields vary by endpoint.
*   `sortOrder` (optional, string, `asc` or `desc`): The sort order. Defaults to `asc`.

---

**Authentication:**
Most API endpoints in Teven will require authentication. We will use JSON Web Tokens (JWT) for authentication. The JWT will be included in the `Authorization` header of the HTTP request in the format: `Bearer <token>`. Endpoints not requiring authentication are explicitly marked.

### I. Authentication and Authorization API

* `POST /api/users/register`: Register a new user.
    * Authentication: Not required.
    * Request:
        <!-- DATA_MODEL_CreateUserRequest -->
    * Response:
        <!-- DATA_MODEL_UserResponse -->

* `POST /api/users/login`: Authenticate a user and return a token.
    * Authentication: Not required.
    * Request:
        <!-- DATA_MODEL_LoginRequest -->
    * Response:
        <!-- DATA_MODEL_LoginResponse -->

* `GET /api/users/{user_id}`: Retrieve user details.
    * Authentication: Required.
    * Permissions: `MANAGE_USERS_SELF` to view your own profile, `VIEW_USERS_ORGANIZATION` to view others in your org, or `VIEW_USERS_GLOBAL` to view anyone.
    * Response:
        <!-- DATA_MODEL_UserResponse -->

* `GET /api/users`: Retrieve all users.
    * Authentication: Required.
    * Permissions: `VIEW_USERS_ORGANIZATION` to view users in your org, or `VIEW_USERS_GLOBAL` to view all users.
    * Query Parameters:
        * See [Common Search, Sort, and Pagination Parameters](#common-search-sort-and-pagination-parameters)
        * `organizationId` (optional, integer): Filter users by organization. Requires `VIEW_USERS_GLOBAL` permission.
    * Response: `PaginatedResponse<UserResponse>`

* `PUT /api/users/{user_id}`: Update user details.
    * Authentication: Required.
    * Permissions: `MANAGE_USERS_SELF` to edit your own profile, `MANAGE_USERS_ORGANIZATION` to edit others in your org, or `MANAGE_USERS_GLOBAL` to edit anyone.
    * Request:
        <!-- DATA_MODEL_UpdateUserRequest -->
    * Response:
        <!-- DATA_MODEL_UserResponse -->

* `GET /api/users/context`: Retrieve context data for the logged-in user.
    * Authentication: Required.
    * Response:
        <!-- DATA_MODEL_LoggedInContextResponse -->

---

### II. Invitation API

* `POST /api/invitations`: Create a new invitation.
    * Authentication: Required.
    * Permissions: `MANAGE_INVITATIONS_ORGANIZATION` or `MANAGE_INVITATIONS_GLOBAL`.
    * Request:
        <!-- DATA_MODEL_CreateInvitationRequest -->
    * Response:
        <!-- DATA_MODEL_InvitationResponse -->

* `GET /api/invitations`: Retrieve all unused invitations for the user's organization.
    * Authentication: Required.
    * Permissions: `MANAGE_INVITATIONS_ORGANIZATION` or `MANAGE_INVITATIONS_GLOBAL`.
    * Response: `List<InvitationResponse>`

* `GET /api/invitations/validate?token={token}`: Validates an invitation token.
    * Authentication: Not required.
    * Response:
        <!-- DATA_MODEL_ValidateInvitationResponse -->

* `POST /api/invitations/accept`: Accept an invitation and create a new user account.
    * Authentication: Not required.
    * Request:
        <!-- DATA_MODEL_AcceptInvitationRequest -->
    * Response:
        <!-- DATA_MODEL_AcceptInvitationResponse -->

* `DELETE /api/invitations/{invitationId}`: Deletes an unused invitation.
    * Authentication: Required.
    * Permissions: `MANAGE_INVITATIONS_ORGANIZATION` or `MANAGE_INVITATIONS_GLOBAL`.
    * Response: `StatusResponse`

---

### III. Event API

* `POST /api/events`: Create a new event.
    * Authentication: Required.
    * Permissions: `MANAGE_EVENTS_ORGANIZATION`
    * Request:
        <!-- DATA_MODEL_CreateEventRequest -->
    * Response:
        <!-- DATA_MODEL_EventResponse -->

* `GET /api/events`: Retrieve all events.
    * Authentication: Required.
    * Permissions: `VIEW_EVENTS_ORGANIZATION`
    * Query Parameters:
        * See [Common Search, Sort, and Pagination Parameters](#common-search-sort-and-pagination-parameters)
        * `startDate` (optional, string, format: YYYY-MM-DD): The start date for the event search.
        * `endDate` (optional, string, format: YYYY-MM-DD): The end date for the event search.
        * `organizationId` (optional, integer): Filter events by organization. Requires `VIEW_EVENTS_GLOBAL` (if not your own org).
    * Response: `PaginatedResponse<EventResponse>`

* `GET /api/events/{eventId}`: Retrieve a specific event.
    * Authentication: Required.
    * Permissions: `VIEW_EVENTS_ORGANIZATION`
    * Response:
        <!-- DATA_MODEL_EventResponse -->

* `PUT /api/events/{eventId}`: Update an event.
    * Authentication: Required.
    * Permissions: `MANAGE_EVENTS_ORGANIZATION`
    * Request:
        <!-- DATA_MODEL_UpdateEventRequest -->
    * Response:
        <!-- DATA_MODEL_EventResponse -->

* `DELETE /api/events/{eventId}`: Delete an event.
    * Authentication: Required.
    * Permissions: `MANAGE_EVENTS_ORGANIZATION`
    * Response: `StatusResponse`

* `POST /api/events/{eventId}/staff/{userId}`: Assign staff to an event.
    * Authentication: Required.
    * Permissions: `ASSIGN_STAFF_TO_EVENTS_ORGANIZATION`
    * Response: `StatusResponse`

* `DELETE /api/events/{eventId}/staff/{userId}`: Remove staff from an event.
    * Authentication: Required.
    * Permissions: `ASSIGN_STAFF_TO_EVENTS_ORGANIZATION`
    * Response: `StatusResponse`

* `POST /api/events/{eventId}/rsvp`: RSVP to an event.
    * Authentication: Required.
    * Request:
        <!-- DATA_MODEL_RsvpRequest -->
    * Response:
        <!-- DATA_MODEL_StatusResponse -->

---

### IV. Customer API

* `GET /api/customers`: Retrieve all customers.
    * Authentication: Required.
    * Permissions: `VIEW_CUSTOMERS_ORGANIZATION`
    * Query Parameters:
        * See [Common Search, Sort, and Pagination Parameters](#common-search-sort-and-pagination-parameters)
        * `organizationId` (optional, integer): Filter customers by organization. Requires `VIEW_CUSTOMERS_GLOBAL` permission.
    * Response: `PaginatedResponse<CustomerResponse>`

* `GET /api/customers/{customerId}`: Retrieve a specific customer.
    * Authentication: Required.
    * Permissions: `VIEW_CUSTOMERS_ORGANIZATION`
    * Response:
        <!-- DATA_MODEL_CustomerResponse -->

* `POST /api/customers`: Create a new customer.
    * Authentication: Required.
    * Permissions: `MANAGE_CUSTOMERS_ORGANIZATION`
    * Request:
        <!-- DATA_MODEL_CreateCustomerRequest -->
    * Response:
        <!-- DATA_MODEL_CustomerResponse -->

* `PUT /api/customers/{customerId}`: Update a customer.
    * Authentication: Required.
    * Permissions: `MANAGE_CUSTOMERS_ORGANIZATION`
    * Request:
        <!-- DATA_MODEL_UpdateCustomerRequest -->
    * Response:
        <!-- DATA_MODEL_CustomerResponse -->

* `DELETE /api/customers/{customerId}`: Delete a customer.
    * Authentication: Required.
    * Permissions: `MANAGE_CUSTOMERS_ORGANIZATION`
    * Response: `StatusResponse`

---

### V. Inventory API

* `GET /api/inventory`: Retrieve all inventory items.
    * Authentication: Required.
    * Permissions: `VIEW_INVENTORY_ORGANIZATION`
    * Query Parameters:
        * See [Common Search, Sort, and Pagination Parameters](#common-search-sort-and-pagination-parameters)
        * `organizationId` (optional, integer): Filter inventory items by organization. Requires `VIEW_INVENTORY_GLOBAL` permission.
    * Response: `PaginatedResponse<InventoryItemResponse>`

* `GET /api/inventory/{inventoryId}`: Retrieve a specific inventory item.
    * Authentication: Required.
    * Permissions: `VIEW_INVENTORY_ORGANIZATION`
    * Response:
        <!-- DATA_MODEL_InventoryItemResponse -->

* `POST /api/inventory`: Create a new inventory item.
    * Authentication: Required.
    * Permissions: `MANAGE_INVENTORY_ORGANIZATION`
    * Request:
        <!-- DATA_MODEL_CreateInventoryItemRequest -->
    * Response:
        <!-- DATA_MODEL_InventoryItemResponse -->

* `PUT /api/inventory/{inventoryId}`: Update an inventory item.
    * Authentication: Required.
    * Permissions: `MANAGE_INVENTORY_ORGANIZATION`
    * Request:
        <!-- DATA_MODEL_UpdateInventoryItemRequest -->
    * Response:
        <!-- DATA_MODEL_InventoryItemResponse -->

* `DELETE /api/inventory/{inventoryId}`: Delete an inventory item.
    * Authentication: Required.
    * Permissions: `MANAGE_INVENTORY_ORGANIZATION`
    * Response: `StatusResponse`

* `POST /api/inventory/{inventoryId}/usage`: Track inventory item usage.
    * Authentication: Required.
    * Permissions: `MANAGE_INVENTORY_ORGANIZATION`
    * Request:
        <!-- DATA_MODEL_TrackInventoryUsageRequest -->
    * Response:
        <!-- DATA_MODEL_StatusResponse -->

---

### VI. Report API

* `POST /api/reports/staff_hours`: Generate a report of staff hours worked within a date range.
    * Authentication: Required.
    * Permissions: `VIEW_REPORTS_ORGANIZATION`
    * Request:
        <!-- DATA_MODEL_StaffHoursReportRequest -->
    * Response: `List<StaffHoursReportResponse>`

* `GET /api/reports/inventory_usage`: Generate a report of inventory usage frequency.
    * Authentication: Required.
    * Permissions: `VIEW_REPORTS_ORGANIZATION`
    * Response: `List<InventoryUsageReportResponse>`

---

### VII. Role Management API

* `POST /api/roles`: Create a new role.
    * Authentication: Required.
    * Permissions: `MANAGE_ROLES_GLOBAL`
    * Request:
        <!-- DATA_MODEL_CreateRoleRequest -->
    * Response:
        <!-- DATA_MODEL_RoleResponse -->

* `GET /api/roles`: Retrieve all roles.
    * Authentication: Required.
    * Permissions: `VIEW_ROLES_ORGANIZATION` or `VIEW_ROLES_GLOBAL`
    * Response: `List<RoleResponse>`

* `GET /api/roles/{roleId}`: Get a role by ID.
    * Authentication: Required.
    * Permissions: `VIEW_ROLES_ORGANIZATION` or `VIEW_ROLES_GLOBAL`
    * Response:
        <!-- DATA_MODEL_RoleResponse -->

* `PUT /api/roles/{roleId}`: Update a role.
    * Authentication: Required.
    * Permissions: `MANAGE_ROLES_GLOBAL`
    * Request:
        <!-- DATA_MODEL_UpdateRoleRequest -->
    * Response:
        <!-- DATA_MODEL_RoleResponse -->

* `DELETE /api/roles/{roleId}`: Delete a role.
    * Authentication: Required.
    * Permissions: `MANAGE_ROLES_GLOBAL`
    * Response: `StatusResponse`

* `POST /api/users/{userId}/roles`: Assign a role to a user.
    * Authentication: Required.
    * Permissions: `ASSIGN_ROLES_ORGANIZATION` or `ASSIGN_ROLES_GLOBAL`
    * Request:
        <!-- DATA_MODEL_AssignRoleRequest -->
    * Response:
        <!-- DATA_MODEL_StatusResponse -->

* `DELETE /api/users/{userId}/roles/{roleId}`: Remove a role from a user.
    * Authentication: Required.
    * Permissions: `ASSIGN_ROLES_ORGANIZATION` or `ASSIGN_ROLES_GLOBAL`
    * Response: `StatusResponse`

---

### VIII. Organization Management API (SuperAdmin Only)

* `POST /api/organizations`: Create a new organization.
    * Authentication: Required.
    * Permissions: `MANAGE_ORGANIZATIONS_GLOBAL`
    * Request:
        <!-- DATA_MODEL_CreateOrganizationRequest -->
    * Response:
        <!-- DATA_MODEL_OrganizationResponse -->

* `GET /api/organizations`: Retrieve all organizations.
    * Authentication: Required.
    * Permissions: `VIEW_ORGANIZATIONS_GLOBAL`
    * Query Parameters:
        * See [Common Search, Sort, and Pagination Parameters](#common-search-sort-and-pagination-parameters)
    * Response: `PaginatedResponse<OrganizationResponse>`

* `GET /api/organizations/{organizationId}`: Retrieve a specific organization.
    * Authentication: Required.
    * Permissions: `VIEW_ORGANIZATIONS_GLOBAL`
    * Response:
        <!-- DATA_MODEL_OrganizationResponse -->

* `PUT /api/organizations/{organizationId}`: Update an organization.
    * Authentication: Required.
    * Permissions: `MANAGE_ORGANIZATIONS_GLOBAL`
    * Request:
        <!-- DATA_MODEL_UpdateOrganizationRequest -->
    * Response:
        <!-- DATA_MODEL_OrganizationResponse -->

* `DELETE /api/organizations/{organizationId}`: Delete an organization.
    * Authentication: Required.
    * Permissions: `MANAGE_ORGANIZATIONS_GLOBAL`
    * Response: `StatusResponse`

---

<!-- INJECT_API_MODELS_HERE -->

---

### API Documentation Generation

This `API.md` file is generated automatically from the `API_TEMPLATE.md` file and the backend route definitions.

To regenerate the `API.md` file, run the following command from the root of the project:

```bash
./gradlew generateApiDocs
```

---

**Notes:**

* This is a preliminary design and is subject to change.
* Error handling (e.g., 400 Bad Request, 404 Not Found, 500 Internal Server Error) is not detailed here but should be implemented for all endpoints.
* Input validation should be performed for all requests.
* Pagination should be implemented for endpoints that return large lists of data (e.g., `/api/events`, `/api/customers`, `/api/inventory`).
* Consider using a more descriptive name for "Availability Functionality" (e.g., "StaffAvailability").