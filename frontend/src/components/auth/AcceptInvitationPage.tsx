import React, { useState, useEffect } from 'react';
import { useNavigate, useLocation } from 'react-router-dom';
import { InvitationService } from '../../api/InvitationService';
import ErrorDisplay from '../common/ErrorDisplay';
import type { ValidateInvitationResponse } from '../../types/api';

import AlreadyLoggedInError from '../common/AlreadyLoggedInError';
import { useAuth } from '../../AuthContext';

const AcceptInvitationPage: React.FC = () => {
  const navigate = useNavigate();
  const location = useLocation();
  const { userContext, loading: authLoading } = useAuth();
  const [token, setToken] = useState<string | null>(null);
  const [invitationDetails, setInvitationDetails] = useState<ValidateInvitationResponse | null>(null);
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [email, setEmail] = useState('');
  const [displayName, setDisplayName] = useState('');
  const [error, setError] = useState<{ message: string; details?: string } | null>(null);
  const [loading, setLoading] = useState<boolean>(false);
  const [successMessage, setSuccessMessage] = useState<string | null>(null);
  const [alreadyLoggedIn, setAlreadyLoggedIn] = useState<boolean>(false);

  const [validationError, setValidationError] = useState<string | null>(null);

  useEffect(() => {
    if (!authLoading && userContext) {
      setAlreadyLoggedIn(true);
    }
  }, [userContext, authLoading]);

  useEffect(() => {
    const queryParams = new URLSearchParams(location.search);
    const invitationToken = queryParams.get('token');
    if (invitationToken) {
      setToken(invitationToken);
      InvitationService.validateInvitation(invitationToken)
        .then((response) => {
          setInvitationDetails(response);
        })
        .catch((err) => {
          setValidationError(err.message || 'Invalid or expired invitation token.');
        });
    } else {
      setError({ message: 'Invitation token not found in URL.' });
    }
  }, [location.search]);

  const handleSubmit = async (event: React.FormEvent) => {
    event.preventDefault();
    setError(null);
    setSuccessMessage(null);
    setAlreadyLoggedIn(false);

    if (!token) {
      setError({ message: 'Invitation token is missing.' });
      return;
    }

    setLoading(true);
    try {
      const response = await InvitationService.acceptInvitation({
        token,
        username,
        password,
        email,
        displayName,
      });

      if (response.success) {
        setSuccessMessage(response.message || 'Invitation accepted! You can now log in.');
        setTimeout(() => navigate('/login'), 3000); // Redirect to login after 3 seconds
      } else {
        setError({ message: response.message || 'Failed to accept invitation.' });
      }
    } catch (err: any) {
      if (err.message === 'Cannot accept invitation while logged in.') {
        setAlreadyLoggedIn(true);
      } else {
        setError({ message: err.message || 'An unexpected error occurred.' });
      }
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="container mt-5">
      <div className="row justify-content-center">
        <div className="col-md-6">
          <div className="card">
            <div className="card-body">
              <h2 className="card-title text-center mb-4">Accept Invitation</h2>
              {validationError && <ErrorDisplay error={{ message: validationError }} />}
              {alreadyLoggedIn ? (
                <AlreadyLoggedInError />
              ) : (
                <>
                  {error && <ErrorDisplay error={error} />}
                  {successMessage && <div className="alert alert-success">{successMessage}</div>}

                  {!invitationDetails && !validationError ? (
                    <div className="alert alert-info">Loading invitation...</div>
                  ) : invitationDetails && !successMessage && !validationError ? (
                    <>
                      <div className="alert alert-info">
                        <p>You have been invited to join <strong>{invitationDetails.organizationName}</strong> as a <strong>{invitationDetails.roleName}</strong>.</p>
                        <p className="mb-0">Please create your account below.</p>
                      </div>
                      <form onSubmit={handleSubmit}>
                        <div className="mb-3">
                          <label htmlFor="username" className="form-label">Username</label>
                          <input
                            type="text"
                            className="form-control"
                            id="username"
                            value={username}
                            onChange={(e) => setUsername(e.target.value)}
                            required
                            disabled={loading}
                          />
                        </div>
                        <div className="mb-3">
                          <label htmlFor="password" className="form-label">Password</label>
                          <input
                            type="password"
                            className="form-control"
                            id="password"
                            value={password}
                            onChange={(e) => setPassword(e.target.value)}
                            required
                            disabled={loading}
                          />
                        </div>
                        <div className="mb-3">
                          <label htmlFor="email" className="form-label">Email</label>
                          <input
                            type="email"
                            className="form-control"
                            id="email"
                            value={email}
                            onChange={(e) => setEmail(e.target.value)}
                            required
                            disabled={loading}
                          />
                        </div>
                        <div className="mb-3">
                          <label htmlFor="displayName" className="form-label">Display Name</label>
                          <input
                            type="text"
                            className="form-control"
                            id="displayName"
                            value={displayName}
                            onChange={(e) => setDisplayName(e.target.value)}
                            required
                            disabled={loading}
                          />
                        </div>
                        <button type="submit" className="btn btn-primary w-100" disabled={loading}>
                          {loading ? 'Accepting...' : 'Accept Invitation'}
                        </button>
                      </form>
                    </>
                  ) : null}
                </>
              )}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

export default AcceptInvitationPage;
