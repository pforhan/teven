import React, { createContext, useContext, useState, useMemo } from 'react';
import type { OrganizationResponse } from './types/organizations';

interface OrganizationContextType {
  selectedOrganization: OrganizationResponse | null;
  setSelectedOrganization: (organization: OrganizationResponse | null) => void;
}

const OrganizationContext = createContext<OrganizationContextType | undefined>(undefined);

export const OrganizationProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [selectedOrganization, setSelectedOrganization] = useState<OrganizationResponse | null>(null);

  const value = useMemo(() => ({
    selectedOrganization,
    setSelectedOrganization,
  }), [selectedOrganization]);

  return (
    <OrganizationContext.Provider value={value}>
      {children}
    </OrganizationContext.Provider>
  );
};

export const useOrganization = () => {
  const context = useContext(OrganizationContext);
  if (context === undefined) {
    throw new Error('useOrganization must be used within an OrganizationProvider');
  }
  return context;
};
