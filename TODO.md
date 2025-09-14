# TODO

This document tracks design questions and areas that need further clarification.

- **Users in multiple organizations:** We'd like a user to be able to be a member of multiple organizations.  They should have an organization selector upon login and a button to switch organizations.  We could use this for superadmins to be able to see a single organization as an organizer does as well. 
- **Reporting details:** The specific requirements for the reports (e.g., filtering, sorting, data visualization) need to be defined.
- **Error handling:** A consistent strategy for displaying errors to the user needs to be designed.
- **UI/UX details:** Specific UI/UX details, such as pagination, sorting, and filtering for the lists of data, need to be fleshed out.
- **Backend Tests:** Implement comprehensive unit and integration tests for all backend services and routes.
- **Frontend Tests:** Implement comprehensive unit and integration tests for all frontend components and services.
- **User invites:** Provide a mechanism to send a single-use URL to users for invites.  Allow management of current invites, perhaps on the users page.
- **Inventory checks:** The service should ensure inventory isn't used in the same place at the same time during event creation or editing.
- **Request Event RSVPS:** an organizer should be able to select a number of employees when creating or editing an event, and specifically request their response.  Could be a new RSVP type of "requested" 
---

  **Completed:**

- **Permissions granularity:** The exact permissions for each role (e.g., "organizer", "staff") need to be defined. For example, can a staff member view all events, or only those they are assigned to? Can they edit event details?
- **Organization Management:** Implemented full CRUD operations for organizations, accessible only by SuperAdmins.
- **SuperAdmin UI:** Implemented a dedicated SuperAdmin dashboard for managing organizations and potentially other global settings.
