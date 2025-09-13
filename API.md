## Teven Service APIs

This document outlines the API endpoints for the Teven service, including their purpose, authentication requirements, and the expected request/response data structures. Data structures are presented using Kotlin pseudocode for conciseness.

**Authentication:**
Most API endpoints in Teven will require authentication. We will use JSON Web Tokens (JWT) for authentication. The JWT will be included in the `Authorization` header of the HTTP request in the format: `Bearer <token>`. Endpoints not requiring authentication are explicitly marked.

### I. Authentication and Authorization API

* `POST /api/users/register`: Register a new user.
    * Authentication: Not required.
    * Request:
        ```kotlin
        data class CreateUserRequest(
          val username: String, 
          val password: String, 
          val email: String, 
          val displayName: String, 
          val roles: List<String> = emptyList(
        ), 
          val organizationId: Int
        )
        ```
    * Response:
        ```kotlin
        data class UserResponse(
          val userId: Int, 
          val username: String, 
          val email: String, 
          val displayName: String, 
          val roles: List<String>, 
          val staffDetails: StaffDetails?, 
          val organization: OrganizationResponse
        )
        ```

* `POST /api/users/login`: Authenticate a user and return a token.
    * Authentication: Not required.
    * Request:
        ```kotlin
        data class LoginRequest(
          val username: String, 
          val password: String
        )
        ```
    * Response:
        ```kotlin
        data class LoginResponse(
          val token: String, 
          val user: UserResponse
        )
        ```

* `GET /api/users/{user_id}`: Retrieve user details.
    * Authentication: Required.
    * Permissions: `MANAGE_USERS_SELF` to view your own profile, `VIEW_USERS_ORGANIZATION` to view others in your org, or `VIEW_USERS_GLOBAL` to view anyone.
    * Response:
        ```kotlin
        data class UserResponse(
          val userId: Int, 
          val username: String, 
          val email: String, 
          val displayName: String, 
          val roles: List<String>, 
          val staffDetails: StaffDetails?, 
          val organization: OrganizationResponse
        )
        ```

* `GET /api/users`: Retrieve all users.
    * Authentication: Required.
    * Permissions: `VIEW_USERS_ORGANIZATION` to view users in your org, or `VIEW_USERS_GLOBAL` to view all users.
    * Response: `List<UserResponse>`

* `PUT /api/users/{user_id}`: Update user details.
    * Authentication: Required.
    * Permissions: `MANAGE_USERS_SELF` to edit your own profile, `MANAGE_USERS_ORGANIZATION` to edit others in your org, or `MANAGE_USERS_GLOBAL` to edit anyone.
    * Request:
        ```kotlin
        data class UpdateUserRequest(
          val email: String?, 
          val displayName: String?, 
          val roles: List<String>?, 
          val staffDetails: UpdateStaffDetails?, 
          val organizationId: Int?
        )
        ```
    * Response:
        ```kotlin
        data class UserResponse(
          val userId: Int, 
          val username: String, 
          val email: String, 
          val displayName: String, 
          val roles: List<String>, 
          val staffDetails: StaffDetails?, 
          val organization: OrganizationResponse
        )
        ```

* `GET /api/users/context`: Retrieve context data for the logged-in user.
    * Authentication: Required.
    * Response:
        ```kotlin
        data class LoggedInContextResponse(
          val user: UserResponse, 
          val permissions: List<String>
        )
        ```

---

### II. Event API

* `POST /api/events`: Create a new event.
    * Authentication: Required.
    * Permissions: `MANAGE_EVENTS_ORGANIZATION`
    * Request:
        ```kotlin
        data class CreateEventRequest(
          val title: String, 
          val date: String, 
          val time: String, 
          val location: String, 
          val description: String, 
          val inventoryIds: List<Int>, 
          val customerId: Int, 
          val staffInvites: StaffInviteDetails, 
          val organizationId: Int
        )
        ```
    * Response:
        ```kotlin
        data class EventResponse(
          val eventId: Int, 
          val title: String, 
          val date: String, 
          val time: String, 
          val location: String, 
          val description: String, 
          val inventoryItems: List<EventInventoryItem>, 
          val customerId: Int, 
          val assignedStaffIds: List<Int>, 
          val rsvps: List<RsvpStatus>, 
          val organization: OrganizationResponse
        )
        ```

* `GET /api/events`: Retrieve all events.
    * Authentication: Required.
    * Permissions: `VIEW_EVENTS_ORGANIZATION`
    * Response: `List<EventResponse>`

* `GET /api/events/{eventId}`: Retrieve a specific event.
    * Authentication: Required.
    * Permissions: `VIEW_EVENTS_ORGANIZATION`
    * Response:
        ```kotlin
        data class EventResponse(
          val eventId: Int, 
          val title: String, 
          val date: String, 
          val time: String, 
          val location: String, 
          val description: String, 
          val inventoryItems: List<EventInventoryItem>, 
          val customerId: Int, 
          val assignedStaffIds: List<Int>, 
          val rsvps: List<RsvpStatus>, 
          val organization: OrganizationResponse
        )
        ```

* `PUT /api/events/{eventId}`: Update an event.
    * Authentication: Required.
    * Permissions: `MANAGE_EVENTS_ORGANIZATION`
    * Request:
        ```kotlin
        data class UpdateEventRequest(
          val title: String?, 
          val date: String?, 
          val time: String?, 
          val location: String?, 
          val description: String?, 
          val inventoryIds: List<Int>?, 
          val customerId: Int?, 
          val staffInvites: StaffInviteDetails?, 
          val organizationId: Int?
        )
        ```
    * Response:
        ```kotlin
        data class EventResponse(
          val eventId: Int, 
          val title: String, 
          val date: String, 
          val time: String, 
          val location: String, 
          val description: String, 
          val inventoryItems: List<EventInventoryItem>, 
          val customerId: Int, 
          val assignedStaffIds: List<Int>, 
          val rsvps: List<RsvpStatus>, 
          val organization: OrganizationResponse
        )
        ```

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
        ```kotlin
        data class RsvpRequest(
          val availability: String
        )
        ```
    * Response:
        ```kotlin
        data class StatusResponse(
          val status: String
        )
        ```

---

### III. Customer API

* `GET /api/customers`: Retrieve all customers.
    * Authentication: Required.
    * Permissions: `VIEW_CUSTOMERS_ORGANIZATION`
    * Response: `List<CustomerResponse>`

* `GET /api/customers/{customerId}`: Retrieve a specific customer.
    * Authentication: Required.
    * Permissions: `VIEW_CUSTOMERS_ORGANIZATION`
    * Response:
        ```kotlin
        data class CustomerResponse(
          val customerId: Int, 
          val name: String, 
          val phone: String, 
          val address: String, 
          val notes: String, 
          val organization: OrganizationResponse
        )
        ```

* `POST /api/customers`: Create a new customer.
    * Authentication: Required.
    * Permissions: `MANAGE_CUSTOMERS_ORGANIZATION`
    * Request:
        ```kotlin
        data class CreateCustomerRequest(
          val name: String, 
          val phone: String, 
          val address: String, 
          val notes: String, 
          val organizationId: Int?
        )
        ```
    * Response:
        ```kotlin
        data class CustomerResponse(
          val customerId: Int, 
          val name: String, 
          val phone: String, 
          val address: String, 
          val notes: String, 
          val organization: OrganizationResponse
        )
        ```

* `PUT /api/customers/{customerId}`: Update a customer.
    * Authentication: Required.
    * Permissions: `MANAGE_CUSTOMERS_ORGANIZATION`
    * Request:
        ```kotlin
        data class UpdateCustomerRequest(
          val name: String?, 
          val phone: String?, 
          val address: String?, 
          val notes: String?, 
          val organizationId: Int?
        )
        ```
    * Response:
        ```kotlin
        data class CustomerResponse(
          val customerId: Int, 
          val name: String, 
          val phone: String, 
          val address: String, 
          val notes: String, 
          val organization: OrganizationResponse
        )
        ```

* `DELETE /api/customers/{customerId}`: Delete a customer.
    * Authentication: Required.
    * Permissions: `MANAGE_CUSTOMERS_ORGANIZATION`
    * Response: `StatusResponse`

---

### IV. Inventory API

* `GET /api/inventory`: Retrieve all inventory items.
    * Authentication: Required.
    * Permissions: `VIEW_INVENTORY_ORGANIZATION`
    * Response: `List<InventoryItemResponse>`

* `GET /api/inventory/{inventoryId}`: Retrieve a specific inventory item.
    * Authentication: Required.
    * Permissions: `VIEW_INVENTORY_ORGANIZATION`
    * Response:
        ```kotlin
        data class InventoryItemResponse(
          val inventoryId: Int, 
          val name: String, 
          val description: String, 
          val quantity: Int, 
          val events: List<EventSummaryResponse>, 
          val organization: OrganizationResponse
        )
        ```

* `POST /api/inventory`: Create a new inventory item.
    * Authentication: Required.
    * Permissions: `MANAGE_INVENTORY_ORGANIZATION`
    * Request:
        ```kotlin
        data class CreateInventoryItemRequest(
          val name: String, 
          val description: String, 
          val quantity: Int, 
          val organizationId: Int?
        )
        ```
    * Response:
        ```kotlin
        data class InventoryItemResponse(
          val inventoryId: Int, 
          val name: String, 
          val description: String, 
          val quantity: Int, 
          val events: List<EventSummaryResponse>, 
          val organization: OrganizationResponse
        )
        ```

* `PUT /api/inventory/{inventoryId}`: Update an inventory item.
    * Authentication: Required.
    * Permissions: `MANAGE_INVENTORY_ORGANIZATION`
    * Request:
        ```kotlin
        data class UpdateInventoryItemRequest(
          val name: String?, 
          val description: String?, 
          val quantity: Int?, 
          val organizationId: Int?
        )
        ```
    * Response:
        ```kotlin
        data class InventoryItemResponse(
          val inventoryId: Int, 
          val name: String, 
          val description: String, 
          val quantity: Int, 
          val events: List<EventSummaryResponse>, 
          val organization: OrganizationResponse
        )
        ```

* `DELETE /api/inventory/{inventoryId}`: Delete an inventory item.
    * Authentication: Required.
    * Permissions: `MANAGE_INVENTORY_ORGANIZATION`
    * Response: `StatusResponse`

* `POST /api/inventory/{inventoryId}/usage`: Track inventory item usage.
    * Authentication: Required.
    * Permissions: `MANAGE_INVENTORY_ORGANIZATION`
    * Request:
        ```kotlin
        data class TrackInventoryUsageRequest(
          val eventId: Int, 
          val quantity: Int
        )
        ```
    * Response:
        ```kotlin
        data class StatusResponse(
          val status: String
        )
        ```

---

### V. Report API

* `POST /api/reports/staff_hours`: Generate a report of staff hours worked within a date range.
    * Authentication: Required.
    * Permissions: `VIEW_REPORTS_ORGANIZATION`
    * Request:
        ```kotlin
        data class StaffHoursReportRequest(
          val startDate: String, 
          val endDate: String
        )
        ```
    * Response: `List<StaffHoursReportResponse>`

* `GET /api/reports/inventory_usage`: Generate a report of inventory usage frequency.
    * Authentication: Required.
    * Permissions: `VIEW_REPORTS_ORGANIZATION`
    * Response: `List<InventoryUsageReportResponse>`

---

### VI. Role Management API

* `POST /api/roles`: Create a new role.
    * Authentication: Required.
    * Permissions: `MANAGE_ROLES_GLOBAL`
    * Request:
        ```kotlin
        data class CreateRoleRequest(
          val roleName: String, 
          val permissions: List<String>
        )
        ```
    * Response:
        ```kotlin
        data class RoleResponse(
          val roleId: Int, 
          val roleName: String, 
          val permissions: List<String>
        )
        ```

* `GET /api/roles`: Retrieve all roles.
    * Authentication: Required.
    * Permissions: `VIEW_ROLES_ORGANIZATION` or `VIEW_ROLES_GLOBAL`
    * Response: `List<RoleResponse>`

* `GET /api/roles/{roleId}`: Get a role by ID.
    * Authentication: Required.
    * Permissions: `VIEW_ROLES_ORGANIZATION` or `VIEW_ROLES_GLOBAL`
    * Response:
        ```kotlin
        data class RoleResponse(
          val roleId: Int, 
          val roleName: String, 
          val permissions: List<String>
        )
        ```

* `PUT /api/roles/{roleId}`: Update a role.
    * Authentication: Required.
    * Permissions: `MANAGE_ROLES_GLOBAL`
    * Request:
        ```kotlin
        data class UpdateRoleRequest(
          val roleName: String?, 
          val permissions: List<String>?
        )
        ```
    * Response:
        ```kotlin
        data class RoleResponse(
          val roleId: Int, 
          val roleName: String, 
          val permissions: List<String>
        )
        ```

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
        ```kotlin
        data class StatusResponse(
          val status: String
        )
        ```

* `DELETE /api/users/{userId}/roles/{roleId}`: Remove a role from a user.
    * Authentication: Required.
    * Permissions: `ASSIGN_ROLES_ORGANIZATION` or `ASSIGN_ROLES_GLOBAL`
    * Response: `StatusResponse`

---

### VII. Organization Management API (SuperAdmin Only)

* `POST /api/organizations`: Create a new organization.
    * Authentication: Required.
    * Permissions: `MANAGE_ORGANIZATIONS_GLOBAL`
    * Request:
        ```kotlin
        data class CreateOrganizationRequest(
          val name: String, 
          val contactInformation: String
        )
        ```
    * Response:
        ```kotlin
        data class OrganizationResponse(
          val organizationId: Int, 
          val name: String, 
          val contactInformation: String
        )
        ```

* `GET /api/organizations`: Retrieve all organizations.
    * Authentication: Required.
    * Permissions: `VIEW_ORGANIZATIONS_GLOBAL`
    * Response: `List<OrganizationResponse>`

* `GET /api/organizations/{organizationId}`: Retrieve a specific organization.
    * Authentication: Required.
    * Permissions: `VIEW_ORGANIZATIONS_GLOBAL`
    * Response:
        ```kotlin
        data class OrganizationResponse(
          val organizationId: Int, 
          val name: String, 
          val contactInformation: String
        )
        ```

* `PUT /api/organizations/{organizationId}`: Update an organization.
    * Authentication: Required.
    * Permissions: `MANAGE_ORGANIZATIONS_GLOBAL`
    * Request:
        ```kotlin
        data class UpdateOrganizationRequest(
          val name: String?, 
          val contactInformation: String?
        )
        ```
    * Response:
        ```kotlin
        data class OrganizationResponse(
          val organizationId: Int, 
          val name: String, 
          val contactInformation: String
        )
        ```

* `DELETE /api/organizations/{organizationId}`: Delete an organization.
    * Authentication: Required.
    * Permissions: `MANAGE_ORGANIZATIONS_GLOBAL`
    * Response: `StatusResponse`

---

### Data Models

```kotlin
data class ApiError(
  val message: String, 
  val details: String?
)

data class ApiResponse<T>(
  val success: Boolean, 
  val data: T?, 
  val error: ApiError?
)

data class CreateCustomerRequest(
  val name: String, 
  val phone: String, 
  val address: String, 
  val notes: String, 
  val organizationId: Int?
)

data class CreateEventRequest(
  val title: String, 
  val date: String, 
  val time: String, 
  val location: String, 
  val description: String, 
  val inventoryIds: List<Int>, 
  val customerId: Int, 
  val staffInvites: StaffInviteDetails, 
  val organizationId: Int
)

data class CreateInventoryItemRequest(
  val name: String, 
  val description: String, 
  val quantity: Int, 
  val organizationId: Int?
)

data class CreateOrganizationRequest(
  val name: String, 
  val contactInformation: String
)

data class CreateRoleRequest(
  val roleName: String, 
  val permissions: List<String>
)

data class CreateUserRequest(
  val username: String, 
  val password: String, 
  val email: String, 
  val displayName: String, 
  val roles: List<String> = emptyList(
), 
  val organizationId: Int
)

data class CustomerResponse(
  val customerId: Int, 
  val name: String, 
  val phone: String, 
  val address: String, 
  val notes: String, 
  val organization: OrganizationResponse
)

data class EventInventoryItem(
  val inventoryId: Int, 
  val quantity: Int
)

data class EventResponse(
  val eventId: Int, 
  val title: String, 
  val date: String, 
  val time: String, 
  val location: String, 
  val description: String, 
  val inventoryItems: List<EventInventoryItem>, 
  val customerId: Int, 
  val assignedStaffIds: List<Int>, 
  val rsvps: List<RsvpStatus>, 
  val organization: OrganizationResponse
)

data class EventSummaryResponse(
  val eventId: Int, 
  val title: String, 
  val quantity: Int
)

data class InventoryItemResponse(
  val inventoryId: Int, 
  val name: String, 
  val description: String, 
  val quantity: Int, 
  val events: List<EventSummaryResponse>, 
  val organization: OrganizationResponse
)

data class InventoryUsageReportResponse(
  val inventoryId: Int, 
  val name: String, 
  val usageCount: Int
)

data class LoggedInContextResponse(
  val user: UserResponse, 
  val permissions: List<String>
)

data class LoginRequest(
  val username: String, 
  val password: String
)

data class LoginResponse(
  val token: String, 
  val user: UserResponse
)

data class Organization(
  val name: String
)

data class OrganizationDetails(
  val organizationId: Int, 
  val name: String, 
  val contactInformation: String
)

data class OrganizationResponse(
  val organizationId: Int, 
  val name: String, 
  val contactInformation: String
)

data class RoleResponse(
  val roleId: Int, 
  val roleName: String, 
  val permissions: List<String>
)

data class RsvpRequest(
  val availability: String
)

data class RsvpStatus(
  val userId: Int, 
  val availability: String
)

data class StaffDetails(
  val contactInformation: String, 
  val skills: List<String>, 
  val hoursWorked: Int, 
  val phoneNumber: String, 
  val dateOfBirth: String
)

data class StaffHoursReportRequest(
  val startDate: String, 
  val endDate: String
)

data class StaffHoursReportResponse(
  val userId: Int, 
  val username: String, 
  val displayName: String, 
  val totalHoursWorked: Int
)

data class StaffInviteDetails(
  val specificStaffIds: List<Int>?, 
  val openInvitation: Boolean = false, 
  val numberOfStaffNeeded: Int
)

data class StatusResponse(
  val status: String
)

data class TrackInventoryUsageRequest(
  val eventId: Int, 
  val quantity: Int
)

data class UpdateCustomerRequest(
  val name: String?, 
  val phone: String?, 
  val address: String?, 
  val notes: String?, 
  val organizationId: Int?
)

data class UpdateEventRequest(
  val title: String?, 
  val date: String?, 
  val time: String?, 
  val location: String?, 
  val description: String?, 
  val inventoryIds: List<Int>?, 
  val customerId: Int?, 
  val staffInvites: StaffInviteDetails?, 
  val organizationId: Int?
)

data class UpdateInventoryItemRequest(
  val name: String?, 
  val description: String?, 
  val quantity: Int?, 
  val organizationId: Int?
)

data class UpdateOrganizationRequest(
  val name: String?, 
  val contactInformation: String?
)

data class UpdateRoleRequest(
  val roleName: String?, 
  val permissions: List<String>?
)

data class UpdateStaffDetails(
  val contactInformation: String?, 
  val skills: List<String>?, 
  val phoneNumber: String?, 
  val dateOfBirth: String?
)

data class UpdateUserRequest(
  val email: String?, 
  val displayName: String?, 
  val roles: List<String>?, 
  val staffDetails: UpdateStaffDetails?, 
  val organizationId: Int?
)

data class UserResponse(
  val userId: Int, 
  val username: String, 
  val email: String, 
  val displayName: String, 
  val roles: List<String>, 
  val staffDetails: StaffDetails?, 
  val organization: OrganizationResponse
)
```

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
