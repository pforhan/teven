package alphainterplanetary.teven.core.security

enum class Permission {
  // User Management
  /** Allows a user to view and edit their own profile information. */
  MANAGE_USERS_SELF,

  /** Allows a user to view other users within their own organization. */
  VIEW_USERS_ORGANIZATION,

  /** Allows a user to create, edit, and deactivate other users within their own organization. */
  MANAGE_USERS_ORGANIZATION,

  /** Allows a user to view all users across all organizations. Typically for Super Admins. */
  VIEW_USERS_GLOBAL,

  /** Allows a user to create, edit, and deactivate users across all organizations. Typically for Super Admins. */
  MANAGE_USERS_GLOBAL,

  // Role Management
  /** Allows a user to view roles within their own organization. */
  VIEW_ROLES_ORGANIZATION,

  /** Allows a user to create, edit, and delete roles within their own organization. This does not grant the ability to assign roles. */
  MANAGE_ROLES_ORGANIZATION,

  /** Allows a user to assign or unassign roles to users within their own organization. */
  ASSIGN_ROLES_ORGANIZATION,

  /** Allows a user to view all roles across all organizations. */
  VIEW_ROLES_GLOBAL,

  /** Allows a user to create, edit, and delete roles across all organizations. */
  MANAGE_ROLES_GLOBAL,

  /** Allows a user to assign or unassign roles to any user in any organization. */
  ASSIGN_ROLES_GLOBAL,

  // Organization Management
  /** Allows a user to view all organizations in the system. */
  VIEW_ORGANIZATIONS_GLOBAL,

  /** Allows a user to create, edit, and deactivate organizations. */
  MANAGE_ORGANIZATIONS_GLOBAL,

  // Customer Management
  /** Allows a user to view customers within their own organization. */
  VIEW_CUSTOMERS_ORGANIZATION,

  /** Allows a user to create, edit, and delete customers within their own organization. */
  MANAGE_CUSTOMERS_ORGANIZATION,

  /** Allows a user to view all customers across all organizations. Typically for Super Admins. */
  VIEW_CUSTOMERS_GLOBAL,

  /** Allows a user to create, edit, and delete customers across all organizations. Typically for Super Admins. */
  MANAGE_CUSTOMERS_GLOBAL,

  // Event Management
  /** Allows a user to view events within their own organization. */
  VIEW_EVENTS_ORGANIZATION,

  /** Allows a user to create, edit, and delete events within their own organization. */
  MANAGE_EVENTS_ORGANIZATION,

  /** Allows a user to view all events across all organizations. Typically for Super Admins. */
  VIEW_EVENTS_GLOBAL,

  /** Allows a user to create, edit, and delete events across all organizations. Typically for Super Admins. */
  MANAGE_EVENTS_GLOBAL,

  /** Allows a user to assign staff members to events within their own organization. */
  ASSIGN_STAFF_TO_EVENTS_ORGANIZATION,

  /** Allows a user to assign themselves to events within their own organization. */
  ASSIGN_TO_EVENTS_SELF,

  // Inventory Management
  /** Allows a user to view inventory items within their own organization. */
  VIEW_INVENTORY_ORGANIZATION,

  /** Allows a user to create, edit, and delete inventory items within their own organization. */
  MANAGE_INVENTORY_ORGANIZATION,

  /** Allows a user to view all inventory items across all organizations. Typically for Super Admins. */
  VIEW_INVENTORY_GLOBAL,

  /** Allows a user to create, edit, and delete inventory items across all organizations. Typically for Super Admins. */
  MANAGE_INVENTORY_GLOBAL,

  // Reporting
  /** Allows a user to view and generate reports for their own organization. */
  VIEW_REPORTS_ORGANIZATION
}