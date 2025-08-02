package com.teven.core.security

enum class Permission {
  // User Management
  MANAGE_USERS_SELF,            // User can edit their own profile
  VIEW_USERS_ORGANIZATION,      // Organizer can view users in their org
  MANAGE_USERS_ORGANIZATION,    // Organizer can edit users in their org
  VIEW_USERS_GLOBAL,            // SuperAdmin can view all users
  MANAGE_USERS_GLOBAL,          // SuperAdmin can edit all users

  // Role Management
  VIEW_ROLES_GLOBAL,
  MANAGE_ROLES_GLOBAL,

  // Organization Management
  VIEW_ORGANIZATIONS_GLOBAL,
  MANAGE_ORGANIZATIONS_GLOBAL,

  // Customer Management
  VIEW_CUSTOMERS_ORGANIZATION,
  MANAGE_CUSTOMERS_ORGANIZATION,

  // Event Management
  VIEW_EVENTS_ORGANIZATION,
  MANAGE_EVENTS_ORGANIZATION,
  ASSIGN_STAFF_TO_EVENTS_ORGANIZATION,

  // Inventory Management
  VIEW_INVENTORY_ORGANIZATION,
  MANAGE_INVENTORY_ORGANIZATION,

  // Reporting
  VIEW_REPORTS_ORGANIZATION
}