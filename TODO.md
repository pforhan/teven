# TODO

This document tracks design questions and areas that need further clarification.

- **Permissions granularity:** The exact permissions for each role (e.g., "organizer", "staff") need to be defined. For example, can a staff member view all events, or only those they are assigned to? Can they edit event details?
- **Reporting details:** The specific requirements for the reports (e.g., filtering, sorting, data visualization) need to be defined.
- **Error handling:** A consistent strategy for displaying errors to the user needs to be designed.
- **UI/UX details:** Specific UI/UX details, such as pagination, sorting, and filtering for the lists of data, need to be fleshed out.
- **Backend Tests:** Implement comprehensive unit and integration tests for all backend services and routes.
- **Frontend Tests:** Implement comprehensive unit and integration tests for all frontend components and services.
- **User invites:** Provide a mechanism to send a single-use URL to users for invites.  Allow management of current invites, perhaps on the users page.

---

**Completed:**

- **Organization Management:** Implemented full CRUD operations for organizations, accessible only by SuperAdmins.
- **SuperAdmin UI:** Implemented a dedicated SuperAdmin dashboard for managing organizations and potentially other global settings.
