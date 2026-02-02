import React, { useState, useEffect } from 'react';
import { OrganizationService } from '../../api/OrganizationService';
import type { OrganizationResponse } from '../../types/organizations';
import { useOrganization } from '../../OrganizationContext';

interface QuickOrganizationPickerModalProps {
  show: boolean;
  onHide: () => void;
  onSelect: (org: OrganizationResponse) => void;
}

const QuickOrganizationPickerModal: React.FC<QuickOrganizationPickerModalProps> = ({ show, onHide, onSelect }) => {
  const [organizations, setOrganizations] = useState<OrganizationResponse[]>([]);
  const [searchTerm, setSearchTerm] = useState('');
  const [loading, setLoading] = useState(false);
  const { setSelectedOrganization } = useOrganization();

  useEffect(() => {
    if (show) {
      const fetchOrgs = async () => {
        setLoading(true);
        try {
          const orgs = await OrganizationService.getAllOrganizations();
          setOrganizations(orgs);
        } catch (err) {
          console.error('Failed to fetch organizations', err);
        } finally {
          setLoading(false);
        }
      };
      fetchOrgs();
    }
  }, [show]);

  const filteredOrgs = organizations.filter(org =>
    org.name.toLowerCase().includes(searchTerm.toLowerCase())
  );

  const handleSelect = (org: OrganizationResponse) => {
    setSelectedOrganization(org);
    onSelect(org);
    onHide();
  };

  if (!show) return null;

  return (
    <div className="modal fade show d-block" tabIndex={-1} style={{ backgroundColor: 'rgba(0,0,0,0.5)' }}>
      <div className="modal-dialog modal-dialog-centered">
        <div className="modal-content border-0 shadow">
          <div className="modal-header border-0 pb-0">
            <h5 className="modal-title fw-bold">Select Organization</h5>
            <button type="button" className="btn-close" onClick={onHide}></button>
          </div>
          <div className="modal-body">
            <p className="text-muted small mb-3">Please select which organization this event belongs to.</p>
            <input
              type="text"
              className="form-control mb-3"
              placeholder="Search organizations..."
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
              autoFocus
            />
            {loading ? (
              <div className="text-center py-4">
                <div className="spinner-border text-primary" role="status">
                  <span className="visually-hidden">Loading...</span>
                </div>
              </div>
            ) : (
              <div className="list-group list-group-flush overflow-auto" style={{ maxHeight: '300px' }}>
                {filteredOrgs.length > 0 ? (
                  filteredOrgs.map(org => (
                    <button
                      key={org.organizationId}
                      type="button"
                      className="list-group-item list-group-item-action border-0 px-3 py-2 d-flex justify-content-between align-items-center"
                      onClick={() => handleSelect(org)}
                    >
                      <span>{org.name}</span>
                      <i className="bi bi-chevron-right text-muted"></i>
                    </button>
                  ))
                ) : (
                  <div className="text-center py-4 text-muted">
                    No organizations found.
                  </div>
                )}
              </div>
            )}
          </div>
          <div className="modal-footer border-0">
            <button type="button" className="btn btn-outline-secondary w-100" onClick={onHide}>Cancel</button>
          </div>
        </div>
      </div>
    </div>
  );
};

export default QuickOrganizationPickerModal;
