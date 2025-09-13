import React, { useState } from 'react';
import { AuthService } from '../../api/AuthService';
import type { UserDetailsResponse, UpdateUserRequest } from '../../types/auth';
import ErrorDisplay from '../common/ErrorDisplay';
import { ApiErrorWithDetails } from '../../errors/ApiErrorWithDetails';

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
  const [error, setError] = useState<{ message: string; details?: string } | null>(null);

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

  return (
    <div className="card mt-3">
      <div className="card-body">
        <h3 className="card-title">Edit Profile</h3>
        <ErrorDisplay error={error} />
        <form onSubmit={handleSubmit}>
          <div className="mb-3">
            <label htmlFor="email" className="form-label">Email:</label>
            <input type="email" id="email" className="form-control" value={email} onChange={(e) => setEmail(e.target.value)} required />
          </div>
          {user.staffDetails && (
            <>
              <div className="mb-3">
                <label htmlFor="contactInformation" className="form-label">Contact Information:</label>
                <input type="text" id="contactInformation" className="form-control" value={contactInformation} onChange={(e) => setContactInformation(e.target.value)} />
              </div>
              <div className="mb-3">
                <label htmlFor="phoneNumber" className="form-label">Phone Number:</label>
                <input type="text" id="phoneNumber" className="form-control" value={phoneNumber} onChange={(e) => setPhoneNumber(e.target.value)} />
              </div>
              <div className="mb-3">
                <label htmlFor="dateOfBirth" className="form-label">Date of Birth:</label>
                <input type="date" id="dateOfBirth" className="form-control" value={dateOfBirth} onChange={(e) => setDateOfBirth(e.target.value)} />
              </div>
              <div className="mb-3">
                <label htmlFor="skills" className="form-label">Skills (comma-separated):</label>
                <input type="text" id="skills" className="form-control" value={skills} onChange={(e) => setSkills(e.target.value)} />
              </div>
            </>
          )}
          <button type="submit" className="btn btn-primary">Save Changes</button>
          <button type="button" className="btn btn-secondary ms-2" onClick={onCancel}>Cancel</button>
        </form>
      </div>
    </div>
  );
};

export default EditProfileForm;
