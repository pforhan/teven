// frontend/src/components/profile/Profile.tsx

import React, { useState, useEffect } from 'react';
import { AuthService } from '../../api/AuthService';
import type { UserContextResponse, UserDetailsResponse } from '../../types/auth';
import EditProfileForm from './EditProfileForm';

import ErrorDisplay from '../common/ErrorDisplay';

const Profile: React.FC = () => {
  const [userContext, setUserContext] = useState<UserContextResponse | null>(null);
  const [userDetails, setUserDetails] = useState<UserDetailsResponse | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [isEditing, setIsEditing] = useState(false);

  const fetchUserDetails = async () => {
    try {
      const context = await AuthService.getUserContext();
      setUserContext(context);
      const details = await AuthService.getUserDetails(context.user.userId);
      setUserDetails(details);
      setError(null);
    } catch (err) {
      if (err instanceof Error) {
        setError(err.message);
      } else {
        setError('An unknown error occurred');
      }
    }
  };

  useEffect(() => {
    fetchUserDetails();
  }, []);

  const handleSave = () => {
    setIsEditing(false);
    fetchUserDetails(); // Re-fetch user details after saving
  };

  if (!userContext || !userDetails) {
    return <p>Loading...</p>;
  }

  return (
    <div>
      <h2>Profile</h2>
      <ErrorDisplay message={error} />
      {isEditing ? (
        <EditProfileForm user={userDetails} onSave={handleSave} onCancel={() => setIsEditing(false)} />
      ) : (
        <>
          <div>
            <p><strong>Username:</strong> {userContext.user.username}</p>
            <p><strong>Display Name:</strong> {userContext.user.displayName}</p>
            <p><strong>Email:</strong> {userContext.user.email}</p>
            <p><strong>Roles:</strong> {userContext.user.roles.join(', ')}</p>
            <p><strong>Organization:</strong> {userContext.organization?.name || 'N/A'}</p>
            {userDetails.staffDetails && (
              <>
                <p><strong>Contact Information:</strong> {userDetails.staffDetails.contactInformation}</p>
                <p><strong>Phone Number:</strong> {userDetails.staffDetails.phoneNumber}</p>
                <p><strong>Date of Birth:</strong> {userDetails.staffDetails.dateOfBirth}</p>
                <p><strong>Skills:</strong> {userDetails.staffDetails.skills.join(', ')}</p>
              </>
            )}
          </div>
          <button onClick={() => setIsEditing(true)}>Edit Profile</button>
        </>
      )}
    </div>
  );
};

export default Profile;
