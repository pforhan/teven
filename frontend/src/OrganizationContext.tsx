import React, { createContext, useContext, useState, useMemo } from 'react';
import type { OrganizationResponse } from './types/organizations';

interface OrganizationContextType {
  selectedOrganization: OrganizationResponse | null;
  setSelectedOrganization: (organization: OrganizationResponse | null) => void;
}

const OrganizationContext = createContext<OrganizationContextType | undefined>(undefined);

export const OrganizationProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [selectedOrganization, setSelectedOrganizationState] = useState<OrganizationResponse | null>(() => {
    const saved = localStorage.getItem('selectedOrganization');
    return saved ? JSON.parse(saved) : null;
  });

  const setSelectedOrganization = (organization: OrganizationResponse | null) => {
    setSelectedOrganizationState(organization);
    if (organization) {
      localStorage.setItem('selectedOrganization', JSON.stringify(organization));
    } else {
      localStorage.removeItem('selectedOrganization');
    }
  };

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
