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
          val displayName: String
        )
        ```
    * Response:
        ```kotlin
        data class UserResponse(
          val userId: Int, 
          val username: String, 
          val email: String, 
          val displayName: String, 
          val role: String, 
          val passwordHash: String, 
          val staffDetails: StaffDetails?
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
          val userId: Int, 
          val username: String, 
          val displayName: String, 
          val role: String
        )
        ```

* `GET /api/users/{user_id}`: Retrieve user details.
    * Authentication: Required.
    * Response:
        ```kotlin
        data class UserResponse(
          val userId: Int, 
          val username: String, 
          val email: String, 
          val displayName: String, 
          val role: String, 
          val passwordHash: String, 
          val staffDetails: StaffDetails?
        )
        ```

* `PUT /api/users/{user_id}`: Update user details.
    * Authentication: Required.
    * Request:
        ```kotlin
        data class UpdateUserRequest(
          val email: String?, 
          val displayName: String?, 
          val staffDetails: UpdateStaffDetails?
        )
        ```
    * Response:
        ```kotlin
        data class UserResponse(
          val userId: Int, 
          val username: String, 
          val email: String, 
          val displayName: String, 
          val role: String, 
          val passwordHash: String, 
          val staffDetails: StaffDetails?
        )
        ```

* `GET /api/users/context`: Retrieve context data for the logged-in user.
    * Authentication: Required.
    * Response:
        ```kotlin
        data class LoggedInContextResponse(
          val user: UserResponse, 
          val organization: OrganizationDetails?, 
          val permissions: List<String>
        )
        ```

---

### II. Event API

* `POST /api/events`: Create a new event.
    * Authentication: Required.
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
          val staffInvites: StaffInviteDetails
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
          val inventoryIds: List<Int>, 
          val customerId: Int, 
          val assignedStaffIds: List<Int>, 
          val rsvps: List<RsvpStatus>
        )
        ```

* `GET /api/events`: Retrieve all events.
    * Authentication: Required.
    * Response: `List<EventResponse>`

* `GET /api/events/{eventId}`: Retrieve a specific event.
    * Authentication: Required.
    * Response:
        ```kotlin
        data class EventResponse(
          val eventId: Int, 
          val title: String, 
          val date: String, 
          val time: String, 
          val location: String, 
          val description: String, 
          val inventoryIds: List<Int>, 
          val customerId: Int, 
          val assignedStaffIds: List<Int>, 
          val rsvps: List<RsvpStatus>
        )
        ```

* `PUT /api/events/{eventId}`: Update an event.
    * Authentication: Required.
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
          val staffInvites: StaffInviteDetails?
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
          val inventoryIds: List<Int>, 
          val customerId: Int, 
          val assignedStaffIds: List<Int>, 
          val rsvps: List<RsvpStatus>
        )
        ```

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
    * Response: `List<CustomerResponse>`

* `GET /api/customers/{customerId}`: Retrieve a specific customer.
    * Authentication: Required.
    * Response:
        ```kotlin
        data class CustomerResponse(
          val customerId: Int, 
          val name: String, 
          val contactInformation: String
        )
        ```

* `POST /api/customers`: Create a new customer.
    * Authentication: Required.
    * Request:
        ```kotlin
        data class CreateCustomerRequest(
          val name: String, 
          val contactInformation: String
        )
        ```
    * Response:
        ```kotlin
        data class CustomerResponse(
          val customerId: Int, 
          val name: String, 
          val contactInformation: String
        )
        ```

* `PUT /api/customers/{customerId}`: Update a customer.
    * Authentication: Required.
    * Request:
        ```kotlin
        data class UpdateCustomerRequest(
          val name: String?, 
          val contactInformation: String?
        )
        ```
    * Response:
        ```kotlin
        data class CustomerResponse(
          val customerId: Int, 
          val name: String, 
          val contactInformation: String
        )
        ```

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
    * Response:
        ```kotlin
        data class InventoryItemResponse(
          val inventoryId: Int, 
          val name: String, 
          val description: String, 
          val quantity: Int
        )
        ```

* `POST /api/inventory`: Create a new inventory item.
    * Authentication: Required.
    * Request:
        ```kotlin
        data class CreateInventoryItemRequest(
          val name: String, 
          val description: String, 
          val quantity: Int
        )
        ```
    * Response:
        ```kotlin
        data class InventoryItemResponse(
          val inventoryId: Int, 
          val name: String, 
          val description: String, 
          val quantity: Int
        )
        ```

* `PUT /api/inventory/{inventoryId}`: Update an inventory item.
    * Authentication: Required.
    * Request:
        ```kotlin
        data class UpdateInventoryItemRequest(
          val name: String?, 
          val description: String?, 
          val quantity: Int?
        )
        ```
    * Response:
        ```kotlin
        data class InventoryItemResponse(
          val inventoryId: Int, 
          val name: String, 
          val description: String, 
          val quantity: Int
        )
        ```

* `DELETE /api/inventory/{inventoryId}`: Delete an inventory item.
    * Authentication: Required.
    * Response: `StatusResponse`

* `POST /api/inventory/{inventoryId}/usage`: Track inventory item usage.
    * Authentication: Required.
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

* `GET /api/reports/staff_hours`: Generate a report of staff hours worked within a date range.
    * Authentication: Required.
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
    * Response: `List<InventoryUsageReportResponse>`

---

### VI. Role Management API

* `POST /api/roles`: Create a new role.
    * Authentication: Required.
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
    * Response: `List<RoleResponse>`

* `GET /api/roles/{roleId}`: Get a role by ID.
    * Authentication: Required.
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
    * Response: `StatusResponse`

* `POST /api/users/{userId}/roles`: Assign a role to a user.
    * Authentication: Required.
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
    * Response: `StatusResponse`

---

### VII. Organization Management API (SuperAdmin Only)

* `POST /api/organizations`: Create a new organization.
    * Authentication: Required (SuperAdmin).
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
    * Authentication: Required (SuperAdmin).
    * Response: `List<OrganizationResponse>`

* `GET /api/organizations/{organizationId}`: Retrieve a specific organization.
    * Authentication: Required.
    * Response:
        ```kotlin
        data class OrganizationResponse(
          val organizationId: Int, 
          val name: String, 
          val contactInformation: String
        )
        ```

* `PUT /api/organizations/{organizationId}`: Update an organization.
    * Authentication: Required (SuperAdmin).
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
    * Authentication: Required (SuperAdmin).
    * Response: `StatusResponse`

---

### Data Models

```kotlin
data class CreateCustomerRequest(
  val name: String, 
  val contactInformation: String
)

data class CreateEventRequest(
  val title: String, 
  val date: String, 
  val time: String, 
  val location: String, 
  val description: String, 
  val inventoryIds: List<Int>, 
  val customerId: Int, 
  val staffInvites: StaffInviteDetails
)

data class CreateInventoryItemRequest(
  val name: String, 
  val description: String, 
  val quantity: Int
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
  val displayName: String
)

data class CustomerResponse(
  val customerId: Int, 
  val name: String, 
  val contactInformation: String
)

data class EventResponse(
  val eventId: Int, 
  val title: String, 
  val date: String, 
  val time: String, 
  val location: String, 
  val description: String, 
  val inventoryIds: List<Int>, 
  val customerId: Int, 
  val assignedStaffIds: List<Int>, 
  val rsvps: List<RsvpStatus>
)

data class InventoryItemResponse(
  val inventoryId: Int, 
  val name: String, 
  val description: String, 
  val quantity: Int
)

data class InventoryUsageReportResponse(
  val inventoryId: Int, 
  val name: String, 
  val usageCount: Int
)

data class LoggedInContextResponse(
  val user: UserResponse, 
  val organization: OrganizationDetails?, 
  val permissions: List<String>
)

data class LoginRequest(
  val username: String, 
  val password: String
)

data class LoginResponse(
  val token: String, 
  val userId: Int, 
  val username: String, 
  val displayName: String, 
  val role: String
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
  val contactInformation: String?
)

data class UpdateEventRequest(
  val title: String?, 
  val date: String?, 
  val time: String?, 
  val location: String?, 
  val description: String?, 
  val inventoryIds: List<Int>?, 
  val customerId: Int?, 
  val staffInvites: StaffInviteDetails?
)

data class UpdateInventoryItemRequest(
  val name: String?, 
  val description: String?, 
  val quantity: Int?
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
  val staffDetails: UpdateStaffDetails?
)

data class UserResponse(
  val userId: Int, 
  val username: String, 
  val email: String, 
  val displayName: String, 
  val role: String, 
  val passwordHash: String, 
  val staffDetails: StaffDetails?
)
```

**Notes:**

* This is a preliminary design and is subject to change.
* Error handling (e.g., 400 Bad Request, 404 Not Found, 500 Internal Server Error) is not detailed here but should be implemented for all endpoints.
* Input validation should be performed for all requests.
* Pagination should be implemented for endpoints that return large lists of data (e.g., `/api/events`, `/api/customers`, `/api/inventory`).
* Consider using a more descriptive name for "Availability Functionality" (e.g., "StaffAvailability").
