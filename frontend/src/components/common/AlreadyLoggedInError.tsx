import React from 'react';

const AlreadyLoggedInError: React.FC = () => {
  return (
    <div className="alert alert-danger" role="alert">
      <h4 className="alert-heading">Already Logged In</h4>
      <p>You are already logged in. You cannot accept an invitation while you are logged in.</p>
      <hr />
      <p className="mb-0">Please log out first, and then try the invitation link again.</p>
    </div>
  );
};

export default AlreadyLoggedInError;
