import React from 'react';
import { Link } from 'react-router-dom';

const AlreadyLoggedInError: React.FC = () => {
  return (
    <div className="alert alert-danger" role="alert">
      <h4 className="alert-heading">Already Logged In</h4>
      <p>You are already logged in. You cannot accept an invitation while you are logged in.</p>
      <hr />
      <p className="mb-0">
        You can return to the application by clicking <a href="/">here</a>.
      </p>
    </div>
  );
};

export default AlreadyLoggedInError;
