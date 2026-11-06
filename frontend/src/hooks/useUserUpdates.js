import { useEffect, useRef } from 'react';
import { useAuth } from '../context/AuthContext';

export function useUserUpdates(types, refresh, deckId) {
    const { subscribeToUpdates } = useAuth();
    const refreshRef = useRef(refresh);
    refreshRef.current = refresh;
    const eventTypes = types.join(',');
    useEffect(() => {
        let timer;
        const unsubscribe = subscribeToUpdates(event => {
            const restored = event.type === 'connection.restored';
            if (!restored && !eventTypes.split(',').includes(event.type)) return;
            if (!restored && deckId && String(event.data?.deck_id) !== String(deckId)) return;
            clearTimeout(timer);
            timer = setTimeout(() => {
                Promise.resolve().then(() => refreshRef.current(event)).catch(console.error);
            }, 50);
        });
        return () => { clearTimeout(timer); unsubscribe(); };
    }, [subscribeToUpdates, eventTypes, deckId]);
}
