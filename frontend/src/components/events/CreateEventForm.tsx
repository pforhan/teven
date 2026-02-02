import React, { useState, useEffect } from 'react';
import { useNavigate, useLocation } from 'react-router-dom';
import { EventService } from '../../api/EventService';
import { CustomerService } from '../../api/CustomerService';
import { UserService } from '../../api/UserService';
import type { CreateEventRequest, EventInventoryItem, EventResponse } from '../../types/events';
import type { CustomerResponse, CreateCustomerRequest } from '../../types/customers';
import type { UserResponse } from '../../types/auth';
import ErrorDisplay from '../common/ErrorDisplay';
import InventoryAssociationEditor from '../common/InventoryAssociationEditor';
import { ApiErrorWithDetails } from '../../errors/ApiErrorWithDetails';
import { useAuth, usePermissions } from '../../AuthContext';
import { useOrganization } from '../../OrganizationContext';
import QuickOrganizationPickerModal from '../common/QuickOrganizationPickerModal';

const CreateEventForm: React.FC = () => {
  const navigate = useNavigate();
  const location = useLocation();

  // --- State ---
  const [title, setTitle] = useState('');
  const [date, setDate] = useState(new Date().toISOString().split('T')[0]);
  const [time, setTime] = useState('10:00');
  const [durationMinutes, setDurationMinutes] = useState(120);
  const [eventLocation, setEventLocation] = useState('');
  const [description, setDescription] = useState('');
  const [inventoryItems, setInventoryItems] = useState<EventInventoryItem[]>([]);
  const [customerId, setCustomerId] = useState('');
  const [openInvitation, setOpenInvitation] = useState(false);
  const [numberOfStaffNeeded, setNumberOfStaffNeeded] = useState(0);
  const [selectedUserIds, setSelectedUserIds] = useState<number[]>([]);
  const [selectedOrganizationId, setSelectedOrganizationId] = useState<string>('');

  const [showMoreDetails, setShowMoreDetails] = useState(false);
  const [nearbyEvents, setNearbyEvents] = useState<EventResponse[]>([]);
  const [error, setError] = useState<{ message: string; details?: string } | null>(null);
  const [showOrgPicker, setShowOrgPicker] = useState(false);
  const [locationManuallyEdited, setLocationManuallyEdited] = useState(false);

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

  const { userContext } = useAuth();
  const { hasPermission } = usePermissions();
  const { selectedOrganization } = useOrganization();
  const canManageGlobalEvents = hasPermission('MANAGE_EVENTS_GLOBAL');

  // --- Effects ---
  useEffect(() => {
    const queryParams = new URLSearchParams(location.search);
    const dateParam = queryParams.get('date');
    const startTimeParam = queryParams.get('startTime');
    const endTimeParam = queryParams.get('endTime');

    if (dateParam) setDate(dateParam);
    if (startTimeParam) setTime(startTimeParam);

    if (dateParam && startTimeParam && endTimeParam) {
      const start = new Date(`${dateParam}T${startTimeParam}`);
      const end = new Date(`${dateParam}T${endTimeParam}`);
      const duration = (end.getTime() - start.getTime()) / 60000;
      setDurationMinutes(duration);
    } else {
      const timeParam = queryParams.get('time');
      if (timeParam) setTime(timeParam);
    }
  }, [location.search]);


  useEffect(() => {
    const fetchOrganizations = async () => {
      if (!selectedOrganization && canManageGlobalEvents) {
        // Only trigger modal automatically if we WERE on a specific org and switched to 'All Orgs'
        if (selectedOrganizationId) {
          setShowOrgPicker(true);
        }
        setSelectedOrganizationId('');
      } else if (selectedOrganization) {
        setSelectedOrganizationId(selectedOrganization.organizationId.toString());
        setShowOrgPicker(false);
      } else if (userContext?.user?.organization?.organizationId) {
        setSelectedOrganizationId(userContext.user.organization.organizationId.toString());
        setShowOrgPicker(false);
      }
    };
    fetchOrganizations();
  }, [canManageGlobalEvents, userContext, selectedOrganization]);

  useEffect(() => {
    const fetchCustomers = async () => {
      if (selectedOrganizationId) {
        try {
          const customers = await CustomerService.getAllCustomers(
            undefined,
            'asc',
            parseInt(selectedOrganizationId),
          );
          setAvailableCustomers(customers);
        } catch (err: unknown) {
          console.error("Failed to fetch customers", err);
        }
      }
    };
    fetchCustomers();
  }, [selectedOrganizationId]);

  useEffect(() => {
    const fetchUsers = async () => {
      if (selectedOrganizationId) {
        try {
          const users = await UserService.getAllUsers(parseInt(selectedOrganizationId));
          setAvailableUsers(users);
        } catch (err: unknown) {
          console.error("Failed to fetch users", err);
        }
      }
    };
    fetchUsers();
  }, [selectedOrganizationId]);

  useEffect(() => {
    const fetchNearbyEvents = async () => {
      if (date && selectedOrganizationId) {
        try {
          const response = await EventService.getAllEvents(undefined, undefined, parseInt(selectedOrganizationId), date, date);
          setNearbyEvents(response.items);
        } catch (err) {
          console.error("Failed to fetch nearby events", err);
        }
      }
    };
    fetchNearbyEvents();
  }, [date, selectedOrganizationId]);

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
      if (!locationManuallyEdited) setEventLocation(created.address);
    } catch (err) {
      console.error("Failed to create customer", err);
    }
  };

  const handleCustomerChange = (id: string) => {
    setCustomerId(id);
    const customer = availableCustomers.find(c => c.customerId.toString() === id);
    if (customer && !locationManuallyEdited) {
      setEventLocation(customer.address);
    }
  };

  const handleSubmit = async (event: React.FormEvent) => {
    event.preventDefault();
    setError(null);

    try {
      const organizationIdToUse = parseInt(selectedOrganizationId);
      if (isNaN(organizationIdToUse)) {
        setError({ message: 'Organization must be selected.' });
        return;
      }

      const request: CreateEventRequest = {
        title,
        date,
        time,
        durationMinutes,
        location: eventLocation || undefined,
        description: description || undefined,
        inventoryItems: inventoryItems,
        customerId: customerId ? parseInt(customerId) : undefined,
        staffInvites: {
          openInvitation,
          numberOfStaffNeeded,
          specificStaffIds: selectedUserIds,
        },
        organizationId: organizationIdToUse,
      };

      await EventService.createEvent(request);
      navigate('/events');
    } catch (err: unknown) {
      if (err instanceof ApiErrorWithDetails) {
        setError({ message: err.message, details: err.details });
      } else if (err instanceof Error) {
        setError({ message: err.message });
      } else {
        setError({ message: 'An unknown error occurred' });
      }
    }
  };

  if (canManageGlobalEvents && !selectedOrganizationId) {
    return (
      <div className="container mt-5">
        <div className="card shadow-sm border-0">
          <div className="card-body p-5 text-center">
            <div className="mb-4 text-warning" style={{ fontSize: '4rem' }}>
              <i className="bi bi-building-exclamation"></i>
            </div>
            <h3 className="fw-bold mb-3">Organization Required</h3>
            <p className="text-muted mb-4">
              Please select an organization to proceed with creating an event.
            </p>
            <div className="d-flex gap-2 justify-content-center">
              <button className="btn btn-primary px-4" onClick={() => setShowOrgPicker(true)}>
                Select Organization
              </button>
              <button className="btn btn-outline-secondary px-4" onClick={() => navigate('/events')}>
                Back to Events
              </button>
            </div>
          </div>
        </div>
        <QuickOrganizationPickerModal
          show={showOrgPicker}
          onHide={() => setShowOrgPicker(false)}
          onSelect={(org) => setSelectedOrganizationId(org.organizationId.toString())}
        />
      </div>
    );
  }

  return (
    <div className="container mt-4">
      <div className="row">
        <div className="col-lg-8">
          <div className="card shadow-sm mb-4">
            <div className="card-body p-4">
              <h2 className="card-title mb-4">Create New Event</h2>
              <ErrorDisplay error={error} />

              <form onSubmit={handleSubmit}>
                {/* Step 1: Basics */}
                <div className="mb-4">
                  <label htmlFor="title" className="form-label fw-bold">Notes / Summary</label>
                  <input
                    type="text"
                    id="title"
                    className="form-control form-control-lg"
                    placeholder="Event title or quick notes..."
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

                {/* Show/Hide Details Toggle */}
                {!showMoreDetails ? (
                  <div className="d-flex gap-2">
                    <button type="submit" className="btn btn-primary btn-lg px-4">Quick Save</button>
                    <button
                      type="button"
                      className="btn btn-outline-secondary btn-lg px-4"
                      onClick={() => setShowMoreDetails(true)}
                    >
                      Add More Details...
                    </button>
                  </div>
                ) : (
                  <div className="fade-in">
                    <div className="row mb-4">
                      <div className="col-md-6">
                        <label htmlFor="durationMinutes" className="form-label fw-bold">Duration (min)</label>
                        <input type="number" id="durationMinutes" className="form-control" value={durationMinutes} onChange={(e) => setDurationMinutes(parseInt(e.target.value))} required />
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
                      <input
                        type="text"
                        id="eventLocation"
                        className="form-control"
                        value={eventLocation}
                        onChange={(e) => {
                          setEventLocation(e.target.value);
                          setLocationManuallyEdited(true);
                        }}
                        placeholder="Physical address or venue name"
                      />
                    </div>

                    <div className="mb-4">
                      <label htmlFor="description" className="form-label fw-bold">Full Description</label>
                      <textarea id="description" className="form-control" rows={3} value={description} onChange={(e) => setDescription(e.target.value)} placeholder="Additional event details..." />
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
                      <button type="submit" className="btn btn-primary btn-lg px-5">Create Event</button>
                      <button type="button" className="btn btn-secondary btn-lg" onClick={() => navigate('/events')}>Cancel</button>
                    </div>
                  </div>
                )}
              </form>
            </div>
          </div>
        </div>

        {/* Sidebar: Conflicts/Nearby Events */}
        <div className="col-lg-4">
          <div className="card border-0 bg-light shadow-sm">
            <div className="card-body p-4">
              <h5 className="fw-bold mb-3 text-secondary">Events on {date}</h5>
              {nearbyEvents.length === 0 ? (
                <p className="text-muted small">No other events scheduled for this day.</p>
              ) : (
                <div className="list-group list-group-flush bg-transparent">
                  {[...nearbyEvents].sort((a, b) => a.time.localeCompare(b.time)).map(event => (
                    <div key={event.eventId} className="list-group-item bg-transparent px-0 py-3">
                      <div className="d-flex w-100 justify-content-between">
                        <h6 className="mb-1 fw-bold">{event.title}</h6>
                        <small className="text-primary">{event.time}</small>
                      </div>
                      <p className="mb-1 small text-muted">
                        <i className="bi bi-clock me-1"></i> {event.durationMinutes} min
                        {event.location && <span className="ms-3"><i className="bi bi-geo-alt me-1"></i> {event.location}</span>}
                      </p>
                    </div>
                  ))}
                </div>
              )}
            </div>
          </div>
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
      )
      }

      {/* Staff Modal */}
      {
        showStaffModal && (
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
                    <div className="form-text">Hold Ctrl (Windows) or Cmd (Mac) to select multiple staff members.</div>
                  </div>
                </div>
                <div className="modal-footer border-0">
                  <button type="button" className="btn btn-primary w-100" onClick={() => setShowStaffModal(false)}>Done</button>
                </div>
              </div>
            </div>
          </div>
        )
      }

      {/* Customer Modal */}
      {
        showCustomerModal && (
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
                    <input type="text" className="form-control" value={newCustomerName} onChange={(e) => setNewCustomerName(e.target.value)} placeholder="Full name or company" />
                  </div>
                  <div className="mb-3">
                    <label className="form-label fw-bold small text-uppercase text-muted">Phone</label>
                    <input type="text" className="form-control" value={newCustomerPhone} onChange={(e) => setNewCustomerPhone(e.target.value)} placeholder="(555) 000-0000" />
                  </div>
                  <div className="mb-3">
                    <label className="form-label fw-bold small text-uppercase text-muted">Address</label>
                    <input type="text" className="form-control" value={newCustomerAddress} onChange={(e) => setNewCustomerAddress(e.target.value)} placeholder="Full street address" />
                  </div>
                </div>
                <div className="modal-footer border-0">
                  <button type="button" className="btn btn-outline-secondary" onClick={() => setShowCustomerModal(false)}>Cancel</button>
                  <button type="button" className="btn btn-primary px-4" onClick={handleCreateCustomer} disabled={!newCustomerName}>Create & Select</button>
                </div>
              </div>
            </div>
          </div>
        )
      }

    </div>
  );
};

export default CreateEventForm;
