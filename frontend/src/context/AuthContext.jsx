import { createContext, useState, useEffect, useContext, useCallback, useRef } from 'react';
import { connectUserUpdates } from '../lib/userUpdates';

const AuthContext = createContext(null);

export function AuthProvider({ children }) {
    const [user, setUser] = useState(null);
    const [loading, setLoading] = useState(true);
    const listeners = useRef(new Set());
    const subscribeToUpdates = useCallback(listener => {
        listeners.current.add(listener);
        return () => listeners.current.delete(listener);
    }, []);
    useEffect(() => {
        if (!user) return;
        return connectUserUpdates(
            event => listeners.current.forEach(listener => listener(event)),
            () => setUser(null)
        );
    }, [user]);

    // При загрузке приложения проверяем, есть ли активная сессия
    useEffect(() => {
        fetch('/api/v1/current_user')
            .then(res => res.json())
            .then(data => {
                setUser(data.user);
                setLoading(false);
            })
            .catch(() => setLoading(false));
    }, []);

    const login = (userData) => setUser(userData);
    const logout = () => setUser(null);

    return (
        <AuthContext.Provider value={{ user, login, logout, loading, subscribeToUpdates }}>
            {!loading && children}
        </AuthContext.Provider>
    );
}

export const useAuth = () => useContext(AuthContext);
