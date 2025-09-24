export const Permission = {
  MANAGE_USERS_ORGANIZATION: "MANAGE_USERS_ORGANIZATION",
  // Add other permissions as needed
} as const;

export type Permission = typeof Permission[keyof typeof Permission];