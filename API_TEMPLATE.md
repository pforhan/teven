## Teven Service APIs

This document outlines the API endpoints for the Teven service, including their purpose, authentication requirements, and the expected request/response data structures. Data structures are presented using Kotlin pseudocode for conciseness.

**Authentication:**
Most API endpoints in Teven will require authentication. We will use JSON Web Tokens (JWT) for authentication. The JWT will be included in the `Authorization` header of the HTTP request in the format: `Bearer <token>`. Endpoints not requiring authentication are explicitly marked.

### I. Authentication and Authorization API

* `POST /api/users/register`: Register a new user.
    * Authentication: Not required.
    * Request: <!-- DATA_MODEL_RegisterRequest -->
    * Response: <!-- DATA_MODEL_UserResponse -->

* `POST /api/users/login`: Authenticate a user and return a token.
    * Authentication: Not required.
    * Request: <!-- DATA_MODEL_LoginRequest -->
    * Response: <!-- DATA_MODEL_LoginResponse -->

* `GET /api/users/{user_id}`: Retrieve user details.
    * Authentication: Required.
    * Response: <!-- DATA_MODEL_UserResponse -->

* `PUT /api/users/{user_id}`: Update user details.
    * Authentication: Required.
    * Request: <!-- DATA_MODEL_UpdateUserRequest -->
    * Response: <!-- DATA_MODEL_UserResponse -->

* `GET /api/users/context`: Retrieve context data for the logged-in user.
    * Authentication: Required.
    * Response: <!-- DATA_MODEL_LoggedInContextResponse -->

---

### II. Event API

* `POST /api/events`: Create a new event.
    * Authentication: Required.
    * Request: <!-- DATA_MODEL_CreateEventRequest -->
    * Response: <!-- DATA_MODEL_EventResponse -->

* `GET /api/events`: Retrieve all events.
    * Authentication: Required.
    * Response: `List<EventResponse>`

* `GET /api/events/{eventId}`: Retrieve a specific event.
    * Authentication: Required.
    * Response: <!-- DATA_MODEL_EventResponse -->

* `PUT /api/events/{eventId}`: Update an event.
    * Authentication: Required.
    * Request: <!-- DATA_MODEL_UpdateEventRequest -->
    * Response: <!-- DATA_MODEL_EventResponse -->

* `DELETE /api/events/{eventId}`: Delete an event.
    * Authentication: Required.
    * Response: `StatusResponse`

* `POST /api/events/{eventId}/staff/{userId}`: Assign staff to an event.
    * Authentication: Required.
    * Response: `StatusResponse`

* `DELETE /api/events/{eventId}/staff/{userId}`: Remove staff from an event.
    * Authentication: Required.
    * Response: `StatusResponse`

* `POST /api/events/{eventId}/rsvp`: RSVP to an event.
    * Authentication: Required.
    * Request: <!-- DATA_MODEL_RsvpRequest -->
    * Response: <!-- DATA_MODEL_StatusResponse -->

---

### III. Customer API

* `GET /api/customers`: Retrieve all customers.
    * Authentication: Required.
    * Response: `List<CustomerResponse>`

* `GET /api/customers/{customerId}`: Retrieve a specific customer.
    * Authentication: Required.
    * Response: <!-- DATA_MODEL_CustomerResponse -->

* `POST /api/customers`: Create a new customer.
    * Authentication: Required.
    * Request: <!-- DATA_MODEL_CreateCustomerRequest -->
    * Response: <!-- DATA_MODEL_CustomerResponse -->

* `PUT /api/customers/{customerId}`: Update a customer.
    * Authentication: Required.
    * Request: <!-- DATA_MODEL_UpdateCustomerRequest -->
    * Response: <!-- DATA_MODEL_CustomerResponse -->

* `DELETE /api/customers/{customerId}`: Delete a customer.
    * Authentication: Required.
    * Response: `StatusResponse`

---

### IV. Inventory API

* `GET /api/inventory`: Retrieve all inventory items.
    * Authentication: Required.
    * Response: `List<InventoryItemResponse>`

* `GET /api/inventory/{inventoryId}`: Retrieve a specific inventory item.
    * Authentication: Required.
    * Response: <!-- DATA_MODEL_InventoryItemResponse -->

* `POST /api/inventory`: Create a new inventory item.
    * Authentication: Required.
    * Request: <!-- DATA_MODEL_CreateInventoryItemRequest -->
    * Response: <!-- DATA_MODEL_InventoryItemResponse -->

* `PUT /api/inventory/{inventoryId}`: Update an inventory item.
    * Authentication: Required.
    * Request: <!-- DATA_MODEL_UpdateInventoryItemRequest -->
    * Response: <!-- DATA_MODEL_InventoryItemResponse -->

* `DELETE /api/inventory/{inventoryId}`: Delete an inventory item.
    * Authentication: Required.
    * Response: `StatusResponse`

* `POST /api/inventory/{inventoryId}/usage`: Track inventory item usage.
    * Authentication: Required.
    * Request: <!-- DATA_MODEL_TrackInventoryUsageRequest -->
    * Response: <!-- DATA_MODEL_StatusResponse -->

---

### V. Report API

* `GET /api/reports/staff_hours`: Generate a report of staff hours worked within a date range.
    * Authentication: Required.
    * Request: <!-- DATA_MODEL_StaffHoursReportRequest -->
    * Response: `List<StaffHoursReportResponse>`

* `GET /api/reports/inventory_usage`: Generate a report of inventory usage frequency.
    * Authentication: Required.
    * Response: `List<InventoryUsageReportResponse>`

---

### VI. Role Management API

* `POST /api/roles`: Create a new role.
    * Authentication: Required.
    * Request: <!-- DATA_MODEL_CreateRoleRequest -->
    * Response: <!-- DATA_MODEL_RoleResponse -->

* `GET /api/roles`: Retrieve all roles.
    * Authentication: Required.
    * Response: `List<RoleResponse>`

* `GET /api/roles/{roleId}`: Get a role by ID.
    * Authentication: Required.
    * Response: <!-- DATA_MODEL_RoleResponse -->

* `PUT /api/roles/{roleId}`: Update a role.
    * Authentication: Required.
    * Request: <!-- DATA_MODEL_UpdateRoleRequest -->
    * Response: <!-- DATA_MODEL_RoleResponse -->

* `DELETE /api/roles/{roleId}`: Delete a role.
    * Authentication: Required.
    * Response: `StatusResponse`

* `POST /api/users/{userId}/roles`: Assign a role to a user.
    * Authentication: Required.
    * Request: <!-- DATA_MODEL_AssignRoleRequest -->
    * Response: <!-- DATA_MODEL_StatusResponse -->

* `DELETE /api/users/{userId}/roles/{roleId}`: Remove a role from a user.
    * Authentication: Required.
    * Response: `StatusResponse`

---

### VII. Organization Management API (SuperAdmin Only)

* `POST /api/organizations`: Create a new organization.
    * Authentication: Required (SuperAdmin).
    * Request: <!-- DATA_MODEL_CreateOrganizationRequest -->
    * Response: <!-- DATA_MODEL_OrganizationResponse -->

* `GET /api/organizations`: Retrieve all organizations.
    * Authentication: Required (SuperAdmin).
    * Response: `List<OrganizationResponse>`

* `GET /api/organizations/{organizationId}`: Retrieve a specific organization.
    * Authentication: Required.
    * Response: <!-- DATA_MODEL_OrganizationResponse -->

* `PUT /api/organizations/{organizationId}`: Update an organization.
    * Authentication: Required (SuperAdmin).
    * Request: <!-- DATA_MODEL_UpdateOrganizationRequest -->
    * Response: <!-- DATA_MODEL_OrganizationResponse -->

* `DELETE /api/organizations/{organizationId}`: Delete an organization.
    * Authentication: Required (SuperAdmin).
    * Response: `StatusResponse`

---

<!-- INJECT_API_MODELS_HERE -->

**Notes:**

* This is a preliminary design and is subject to change.
* Error handling (e.g., 400 Bad Request, 404 Not Found, 500 Internal Server Error) is not detailed here but should be implemented for all endpoints.
* Input validation should be performed for all requests.
* Pagination should be implemented for endpoints that return large lists of data (e.g., `/api/events`, `/api/customers`, `/api/inventory`).
* Consider using a more descriptive name for "Availability Functionality" (e.g., "StaffAvailability").
