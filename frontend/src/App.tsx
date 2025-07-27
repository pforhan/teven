import { useState } from 'react'

import './App.css'
import Auth from './Auth'

function App() {
  const [isLoggedIn, setIsLoggedIn] = useState(false);
  const [user, setUser] = useState<any>(null);

  const handleLogin = (token: string, userId: number, username: string, displayName: string, role: string) => {
    setIsLoggedIn(true);
    setUser({ token, userId, username, displayName, role });
    // Optionally store token in localStorage or sessionStorage
    localStorage.setItem('authToken', token);
  };

  const handleLogout = () => {
    setIsLoggedIn(false);
    setUser(null);
    localStorage.removeItem('authToken');
  };

  if (!isLoggedIn) {
    return <Auth onLogin={handleLogin} />;
  }

  return (
    <div className="App">
      <header className="App-header">
        <h1>Teven Scheduling App</h1>
        <nav>
          <ul>
            <li><a href="#events">Events</a></li>
            <li><a href="#customers">Customers</a></li>
            <li><a href="#inventory">Inventory</a></li>
            <li><a href="#reports">Reports</a></li>
            <li><a href="#profile">Profile</a></li>
            <li><button onClick={handleLogout}>Logout</button></li>
          </ul>
        </nav>
      </header>
      <main>
        <section id="events">
          <h2>Events</h2>
          <p>Event listing and management will go here.</p>
        </section>
        <section id="customers">
          <h2>Customers</h2>
          <p>Customer management will go here.</p>
        </section>
        <section id="inventory">
          <h2>Inventory</h2>
          <p>Inventory management will go here.</p>
        </section>
        <section id="reports">
          <h2>Reports</h2>
          <p>Reporting features will go here.</p>
        </section>
        <section id="profile">
          <h2>Profile</h2>
          <p>User profile management will go here.</p>
          {user && (
            <div>
              <p>Welcome, {user.displayName} ({user.username})!</p>
              <p>Role: {user.role}</p>
            </div>
          )}
        </section>
      </main>
      <div className="card">
        <p>
          Edit <code>src/App.tsx</code> and save to test HMR
        </p>
      </div>
      <p className="read-the-docs">
        Click on the Vite and React logos to learn more
      </p>
    </div>
  )
}

export default App