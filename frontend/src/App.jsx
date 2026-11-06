import { BrowserRouter, Routes, Route, Navigate, Outlet } from 'react-router-dom';
import { useAuth } from './context/AuthContext';
import Home from './pages/Home.jsx';
import Login from './pages/Login.jsx';
import Signup from './pages/Signup.jsx';
import Decks from './pages/Decks';
import Deck from './pages/Deck';
import Study from "./pages/Study.jsx";
import Quiz from "./pages/Quiz.jsx";
import Dashboard from './pages/Dashboard.jsx';
import Stats from './pages/Stats.jsx';

function RequireAuth() {
  const { user, loading } = useAuth();
  if (loading) return null;
  return user ? <Outlet /> : <Navigate to="/login" replace />;
}

function App() {
  return (
      <BrowserRouter>
        <Routes>
          <Route path="/" element={<Home />} />
          <Route path="/login" element={<Login />} />
          <Route path="/signup" element={<Signup />} />
          <Route element={<RequireAuth />}>
            <Route path="/dashboard" element={<Dashboard />} />
            <Route path="/decks" element={<Decks />} />
            <Route path="/decks/:id" element={<Deck />} />
            <Route path="/study/:id" element={<Study />} />
            <Route path="/study/:id/quiz" element={<Quiz />} />
            <Route path="/stats" element={<Stats />} />
          </Route>
        </Routes>
      </BrowserRouter>
  );
}

export default App;
