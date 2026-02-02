import React, { useState, useEffect } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { EventService } from '../../api/EventService';
import { OrganizationService } from '../../api/OrganizationService';
import { CustomerService } from '../../api/CustomerService';
import { UserService } from '../../api/UserService';
import type { EventResponse, UpdateEventRequest, EventInventoryItem } from '../../types/events';
import type { OrganizationResponse } from '../../types/organizations';
import type { CustomerResponse, CreateCustomerRequest } from '../../types/customers';
import type { UserResponse } from '../../types/auth';
import ErrorDisplay from '../common/ErrorDisplay';
import InventoryAssociationEditor from '../common/InventoryAssociationEditor';
import { ApiErrorWithDetails } from '../../errors/ApiErrorWithDetails';
import { usePermissions } from '../../AuthContext';
import OtherEventsPanel from './OtherEventsPanel';

const EditEventForm: React.FC = () => {
  const navigate = useNavigate();
  const { eventId } = useParams<{ eventId: string }>();

  // --- State ---
  const [event, setEvent] = useState<EventResponse | null>(null);
  const [title, setTitle] = useState('');
  const [date, setDate] = useState('');
  const [time, setTime] = useState('');
  const [durationMinutes, setDurationMinutes] = useState(60);
  const [eventLocation, setEventLocation] = useState('');
  const [description, setDescription] = useState('');
  const [inventoryItems, setInventoryItems] = useState<EventInventoryItem[]>([]);
  const [customerId, setCustomerId] = useState('');
  const [openInvitation, setOpenInvitation] = useState(false);
  const [numberOfStaffNeeded, setNumberOfStaffNeeded] = useState(0);
  const [selectedUserIds, setSelectedUserIds] = useState<number[]>([]);
  const [selectedOrganizationId, setSelectedOrganizationId] = useState<string>('');

  const [error, setError] = useState<{ message: string; details?: string } | null>(null);

  const [availableOrganizations, setAvailableOrganizations] = useState<OrganizationResponse[]>([]);
  const [availableCustomers, setAvailableCustomers] = useState<CustomerResponse[]>([]);
  const [availableUsers, setAvailableUsers] = useState<UserResponse[]>([]);

  // Modal State
  const [showInventoryModal, setShowInventoryModal] = useState(false);
  const [showStaffModal, setShowStaffModal] = useState(false);
  const [showCustomerModal, setShowCustomerModal] = useState(false);

  // Quick Customer State
  const [newCustomerName, setNewCustomerName] = useState('');
  const [newCustomerPhone, setNewCustomerPhone] = useState('');
  const [newCustomerAddress, setNewCustomerAddress] = useState('');

  const { hasPermission } = usePermissions();
  const canManageGlobalEvents = hasPermission('MANAGE_EVENTS_GLOBAL');

  // --- Effects ---
  useEffect(() => {
    const fetchEventAndContext = async () => {
      if (!eventId) return;
      try {
        const fetchedEvent = await EventService.getEvent(parseInt(eventId));
        setEvent(fetchedEvent);
        setTitle(fetchedEvent.title);
        setDate(fetchedEvent.date);
        setTime(fetchedEvent.time);
        setDurationMinutes(fetchedEvent.durationMinutes || 60);
        setEventLocation(fetchedEvent.location || '');
        setDescription(fetchedEvent.description || '');
        setInventoryItems(fetchedEvent.inventoryItems || []);
        setCustomerId(fetchedEvent.customer?.customerId.toString() || '');
        setOpenInvitation(fetchedEvent.openInvitation || false);
        setNumberOfStaffNeeded(fetchedEvent.numberOfStaffNeeded || 0);
        setSelectedUserIds(fetchedEvent.rsvps?.map(r => r.userId) || []);
        setSelectedOrganizationId(fetchedEvent.organization?.organizationId.toString() || '');

        if (canManageGlobalEvents) {
          const orgs = await OrganizationService.getAllOrganizations();
          setAvailableOrganizations(orgs);
        }
      } catch (err: unknown) {
        if (err instanceof ApiErrorWithDetails) {
          setError({ message: err.message, details: err.details });
        } else {
          setError({ message: 'Failed to fetch event details' });
        }
      }
    };
    fetchEventAndContext();
  }, [eventId, canManageGlobalEvents]);

  useEffect(() => {
    const fetchCustomersAndUsers = async () => {
      if (selectedOrganizationId) {
        try {
          const [customers, users] = await Promise.all([
            CustomerService.getAllCustomers(undefined, 'asc', parseInt(selectedOrganizationId)),
            UserService.getAllUsers(parseInt(selectedOrganizationId))
          ]);
          setAvailableCustomers(customers);
          setAvailableUsers(users);
        } catch (err: unknown) {
          console.error("Failed to fetch context", err);
        }
      }
    };
    fetchCustomersAndUsers();
  }, [selectedOrganizationId]);


  // --- Handlers ---
  const handleCreateCustomer = async () => {
    if (!newCustomerName) return;
    try {
      const request: CreateCustomerRequest = {
        name: newCustomerName,
        phone: newCustomerPhone,
        address: newCustomerAddress,
        notes: '',
        organizationId: parseInt(selectedOrganizationId),
      };
      const created = await CustomerService.createCustomer(request);
      setAvailableCustomers([...availableCustomers, created]);
      setCustomerId(created.customerId.toString());
      setShowCustomerModal(false);
      setNewCustomerName('');
      setNewCustomerPhone('');
      setNewCustomerAddress('');
      if (!eventLocation) setEventLocation(created.address);
    } catch (err) {
      console.error("Failed to create customer", err);
    }
  };

  const handleCustomerChange = (id: string) => {
    setCustomerId(id);
    const customer = availableCustomers.find(c => c.customerId.toString() === id);
    if (customer && !eventLocation) {
      setEventLocation(customer.address);
    }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    if (!eventId) return;

    try {
      const request: UpdateEventRequest = {
        title,
        date,
        time,
        durationMinutes,
        location: eventLocation || undefined,
        description: description || undefined,
        inventoryItems,
        customerId: customerId ? parseInt(customerId) : undefined,
        staffInvites: {
          openInvitation,
          numberOfStaffNeeded,
          specificStaffIds: selectedUserIds,
        },
        organizationId: canManageGlobalEvents && selectedOrganizationId ? parseInt(selectedOrganizationId) : undefined,
      };

      await EventService.updateEvent(parseInt(eventId), request);
      navigate(`/events/${eventId}`);
    } catch (err: unknown) {
      if (err instanceof ApiErrorWithDetails) {
        setError({ message: err.message, details: err.details });
      } else {
        setError({ message: 'Failed to update event' });
      }
    }
  };

  if (!event) {
    return (
      <div className="container mt-5 text-center">
        <div className="spinner-border text-primary" role="status">
          <span className="visually-hidden">Loading...</span>
        </div>
      </div>
    );
  }

  return (
    <div className="container mt-4">
      <div className="row">
        <div className="col-lg-8">
          <div className="card shadow-sm mb-4">
            <div className="card-body p-4">
              <h2 className="card-title mb-4">Edit Event</h2>
              <ErrorDisplay error={error} />

              <form onSubmit={handleSubmit}>
                <div className="mb-4">
                  <label htmlFor="title" className="form-label fw-bold">Notes / Summary</label>
                  <input
                    type="text"
                    id="title"
                    className="form-control form-control-lg"
                    value={title}
                    onChange={(e) => setTitle(e.target.value)}
                    required
                  />
                </div>

                <div className="row mb-4">
                  <div className="col-md-6">
                    <label htmlFor="date" className="form-label fw-bold">Date</label>
                    <input type="date" id="date" className="form-control" value={date} onChange={(e) => setDate(e.target.value)} required />
                  </div>
                  <div className="col-md-6">
                    <label htmlFor="time" className="form-label fw-bold">Start Time</label>
                    <input type="time" id="time" className="form-control" value={time} onChange={(e) => setTime(e.target.value)} required />
                  </div>
                </div>

                <div className="row mb-4">
                  <div className="col-md-6">
                    <label htmlFor="durationMinutes" className="form-label fw-bold">Duration (min)</label>
                    <input type="number" id="durationMinutes" className="form-control" value={durationMinutes} onChange={(e) => setDurationMinutes(parseInt(e.target.value))} required />
                  </div>
                  <div className="col-md-6">
                    <label className="form-label fw-bold">Organization</label>
                    <select
                      className="form-select"
                      value={selectedOrganizationId}
                      onChange={(e) => setSelectedOrganizationId(e.target.value)}
                      required
                      disabled={!canManageGlobalEvents}
                    >
                      {availableOrganizations.map(org => (
                        <option key={org.organizationId} value={org.organizationId}>{org.name}</option>
                      ))}
                    </select>
                  </div>
                </div>

                <div className="mb-4">
                  <label htmlFor="customer" className="form-label fw-bold d-flex justify-content-between">
                    Customer
                    <button type="button" className="btn btn-sm btn-link p-0 text-decoration-none" onClick={() => setShowCustomerModal(true)}>+ New Customer</button>
                  </label>
                  <select
                    id="customer"
                    className="form-select"
                    value={customerId}
                    onChange={(e) => handleCustomerChange(e.target.value)}
                  >
                    <option value="">No Customer Selected</option>
                    {availableCustomers.map(c => (
                      <option key={c.customerId} value={c.customerId}>{c.name}</option>
                    ))}
                  </select>
                </div>

                <div className="mb-4">
                  <label htmlFor="eventLocation" className="form-label fw-bold">Location</label>
                  <input type="text" id="eventLocation" className="form-control" value={eventLocation} onChange={(e) => setEventLocation(e.target.value)} />
                </div>

                <div className="mb-4">
                  <label htmlFor="description" className="form-label fw-bold">Full Description</label>
                  <textarea id="description" className="form-control" rows={3} value={description} onChange={(e) => setDescription(e.target.value)} />
                </div>

                {/* Associations */}
                <div className="row mb-4">
                  <div className="col-md-6">
                    <div className="card bg-light border-0 h-100">
                      <div className="card-body">
                        <h6 className="fw-bold mb-3 d-flex justify-content-between align-items-center">
                          Inventory
                          <button type="button" className="btn btn-sm btn-secondary" onClick={() => setShowInventoryModal(true)}>Manage</button>
                        </h6>
                        {inventoryItems.length === 0 ? (
                          <small className="text-muted">No items added</small>
                        ) : (
                          <ul className="list-unstyled mb-0">
                            {inventoryItems.map(item => (
                              <li key={item.inventoryId} className="mb-1">
                                <span className="badge bg-secondary me-2">{item.quantity}</span> {item.itemName}
                              </li>
                            ))}
                          </ul>
                        )}
                      </div>
                    </div>
                  </div>
                  <div className="col-md-6">
                    <div className="card bg-light border-0 h-100">
                      <div className="card-body">
                        <h6 className="fw-bold mb-3 d-flex justify-content-between align-items-center">
                          Staffing
                          <button type="button" className="btn btn-sm btn-secondary" onClick={() => setShowStaffModal(true)}>Manage</button>
                        </h6>
                        <div className="d-flex gap-2">
                          <span className="badge bg-info text-dark">{numberOfStaffNeeded} total needed</span>
                          <span className="badge bg-primary">{selectedUserIds.length} invited</span>
                        </div>
                        {openInvitation && <div className="mt-2"><small className="badge bg-success">Open Invitation</small></div>}
                      </div>
                    </div>
                  </div>
                </div>

                <div className="d-flex gap-2 mt-4">
                  <button type="submit" className="btn btn-primary btn-lg px-5">Save Changes</button>
                  <button type="button" className="btn btn-secondary btn-lg" onClick={() => navigate(`/events/${eventId}`)}>Cancel</button>
                </div>
              </form>
            </div>
          </div>
        </div>

        {/* Sidebar: Conflicts/Nearby Events */}
        <div className="col-lg-4">
          <OtherEventsPanel
            date={date}
            organizationId={selectedOrganizationId}
            excludeEventId={eventId}
          />
        </div>
      </div>

      {/* --- Modals --- */}

      {/* Inventory Modal */}
      {showInventoryModal && (
        <div className="modal fade show d-block" tabIndex={-1} style={{ backgroundColor: 'rgba(0,0,0,0.5)' }}>
          <div className="modal-dialog modal-dialog-centered">
            <div className="modal-content border-0 shadow">
              <div className="modal-header border-0 pb-0">
                <h5 className="modal-title fw-bold">Manage Inventory</h5>
                <button type="button" className="btn-close" onClick={() => setShowInventoryModal(false)}></button>
              </div>
              <div className="modal-body">
                <InventoryAssociationEditor
                  initialInventoryItems={inventoryItems}
                  onInventoryItemsChange={setInventoryItems}
                  organizationId={selectedOrganizationId}
                />
              </div>
              <div className="modal-footer border-0">
                <button type="button" className="btn btn-primary w-100" onClick={() => setShowInventoryModal(false)}>Done</button>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Staff Modal */}
      {showStaffModal && (
        <div className="modal fade show d-block" tabIndex={-1} style={{ backgroundColor: 'rgba(0,0,0,0.5)' }}>
          <div className="modal-dialog modal-dialog-centered">
            <div className="modal-content border-0 shadow">
              <div className="modal-header border-0 pb-0">
                <h5 className="modal-title fw-bold">Event Staffing</h5>
                <button type="button" className="btn-close" onClick={() => setShowStaffModal(false)}></button>
              </div>
              <div className="modal-body">
                <div className="mb-3">
                  <label htmlFor="numberOfStaffNeeded" className="form-label fw-bold small text-uppercase text-muted">Number of Staff Needed</label>
                  <input
                    type="number"
                    id="numberOfStaffNeeded"
                    className="form-control"
                    value={numberOfStaffNeeded}
                    onChange={(e) => setNumberOfStaffNeeded(parseInt(e.target.value) || 0)}
                  />
                </div>
                <div className="mb-3 form-check">
                  <input
                    type="checkbox"
                    id="openInvitation"
                    className="form-check-input"
                    checked={openInvitation}
                    onChange={(e) => setOpenInvitation(e.target.checked)}
                  />
                  <label htmlFor="openInvitation" className="form-check-label">Open invitation to all staff</label>
                </div>
                <hr />
                <div className="mb-3">
                  <label htmlFor="staffInvites" className="form-label fw-bold small text-uppercase text-muted">Invite Specific Staff</label>
                  <select
                    id="staffInvites"
                    className="form-select"
                    multiple
                    size={6}
                    value={selectedUserIds.map(String)}
                    onChange={(e) => setSelectedUserIds(Array.from(e.target.selectedOptions, (option) => parseInt(option.value)))}
                  >
                    {availableUsers.map(user => (
                      <option key={user.userId} value={user.userId}>{user.displayName}</option>
                    ))}
                  </select>
                </div>
              </div>
              <div className="modal-footer border-0">
                <button type="button" className="btn btn-primary w-100" onClick={() => setShowStaffModal(false)}>Done</button>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Customer Modal */}
      {showCustomerModal && (
        <div className="modal fade show d-block" tabIndex={-1} style={{ backgroundColor: 'rgba(0,0,0,0.5)' }}>
          <div className="modal-dialog modal-dialog-centered">
            <div className="modal-content border-0 shadow">
              <div className="modal-header border-0 pb-0">
                <h5 className="modal-title fw-bold">Create New Customer</h5>
                <button type="button" className="btn-close" onClick={() => setShowCustomerModal(false)}></button>
              </div>
              <div className="modal-body">
                <div className="mb-3">
                  <label className="form-label fw-bold small text-uppercase text-muted">Name</label>
                  <input type="text" className="form-control" value={newCustomerName} onChange={(e) => setNewCustomerName(e.target.value)} />
                </div>
                <div className="mb-3">
                  <label className="form-label fw-bold small text-uppercase text-muted">Phone</label>
                  <input type="text" className="form-control" value={newCustomerPhone} onChange={(e) => setNewCustomerPhone(e.target.value)} />
                </div>
                <div className="mb-3">
                  <label className="form-label fw-bold small text-uppercase text-muted">Address</label>
                  <input type="text" className="form-control" value={newCustomerAddress} onChange={(e) => setNewCustomerAddress(e.target.value)} />
                </div>
              </div>
              <div className="modal-footer border-0">
                <button type="button" className="btn btn-outline-secondary" onClick={() => setShowCustomerModal(false)}>Cancel</button>
                <button type="button" className="btn btn-primary px-4" onClick={handleCreateCustomer} disabled={!newCustomerName}>Create & Select</button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default EditEventForm;