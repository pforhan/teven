// frontend/src/components/profile/EditProfileForm.tsx

import React, { useState } from 'react';
import { AuthService } from '../../api/AuthService';
import type { UserDetailsResponse, UpdateUserRequest } from '../../types/auth';
import ErrorDisplay from '../common/ErrorDisplay';

interface EditProfileFormProps {
  user: UserDetailsResponse;
  onSave: () => void;
  onCancel: () => void;
}

const EditProfileForm: React.FC<EditProfileFormProps> = ({ user, onSave, onCancel }) => {
  const [email, setEmail] = useState(user.email);
  const [contactInformation, setContactInformation] = useState(user.staffDetails?.contactInformation || '');
  const [phoneNumber, setPhoneNumber] = useState(user.staffDetails?.phoneNumber || '');
  const [dateOfBirth, setDateOfBirth] = useState(user.staffDetails?.dateOfBirth || '');
  const [skills, setSkills] = useState(user.staffDetails?.skills.join(', ') || '');
  const [error, setError] = useState<string | null>(null);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);

    try {
      const request: UpdateUserRequest = {
        email,
        staffDetails: {
          contactInformation,
          phoneNumber,
          dateOfBirth,
          skills: skills.split(',').map(s => s.trim()).filter(s => s.length > 0),
        },
      };

      await AuthService.updateUserDetails(user.userId, request);
      onSave();
    } catch (err) {
      if (err instanceof Error) {
        setError(err.message);
      } else {
        setError('An unknown error occurred');
      }
    }
  };

  return (
    <div>
      <h3>Edit Profile</h3>
      <ErrorDisplay message={error} />
      <form onSubmit={handleSubmit}>
        <div>
          <label htmlFor="email">Email:</label>
          <input type="email" id="email" value={email} onChange={(e) => setEmail(e.target.value)} required />
        </div>
        {user.role === 'staff' && (
          <>
            <div>
              <label htmlFor="contactInformation">Contact Information:</label>
              <input type="text" id="contactInformation" value={contactInformation} onChange={(e) => setContactInformation(e.target.value)} />
            </div>
            <div>
              <label htmlFor="phoneNumber">Phone Number:</label>
              <input type="text" id="phoneNumber" value={phoneNumber} onChange={(e) => setPhoneNumber(e.target.value)} />
            </div>
            <div>
              <label htmlFor="dateOfBirth">Date of Birth:</label>
              <input type="date" id="dateOfBirth" value={dateOfBirth} onChange={(e) => setDateOfBirth(e.target.value)} />
            </div>
            <div>
              <label htmlFor="skills">Skills (comma-separated):</label>
              <input type="text" id="skills" value={skills} onChange={(e) => setSkills(e.target.value)} />
            </div>
          </>
        )}
        <button type="submit">Save Changes</button>
        <button type="button" onClick={onCancel}>Cancel</button>
      </form>
    </div>
  );
};

export default EditProfileForm;
