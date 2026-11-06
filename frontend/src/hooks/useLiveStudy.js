import { useCallback, useEffect, useRef, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useUserUpdates } from './useUserUpdates';
import { mergeStudyQueue } from '../lib/studyQueue';

export function useLiveStudy(id, mode) {
    const navigate = useNavigate();
    const [state, setState] = useState({ items: [], loading: true, error: null, answered_count: 0, correct_count: 0 });
    const [saving, setSaving] = useState(false);
    const sessionId = useRef(null);
    const retained = useRef(null);
    const busy = useRef(false);
    const version = useRef(0);
    const mounted = useRef(true);
    const endpoint = mode === 'quiz' ? 'quiz' : 'study';

    const refresh = useCallback(async () => {
        if (busy.current) return;
        const request = ++version.current;
        try {
            const query = sessionId.current ? `?session_id=${sessionId.current}` : '';
            const res = await fetch(`/api/v1/decks/${id}/${endpoint}${query}`, { credentials: 'include' });
            if (!mounted.current || request !== version.current) return;
            if (res.status === 404) { navigate('/decks', { replace: true }); return; }
            if (res.status === 401) { navigate('/login', { replace: true }); return; }
            const data = await res.json();
            if (!mounted.current || request !== version.current) return;
            if (!res.ok) {
                if (res.status === 422) {
                    retained.current = null;
                    setState(previous => ({ ...previous, items: [], loading: false, error: data.error }));
                    return;
                }
                throw new Error(data.error || 'Не удалось обновить занятие.');
            }
            sessionId.current = data.session_id;
            if (data.finished || !data.existing_card_ids?.includes(retained.current?.card_id)) retained.current = null;
            setState(previous => ({
                ...data, loading: false, error: null,
                items: data.finished ? [] : mergeStudyQueue(previous.items, data.cards || data.questions || [], retained.current, data.existing_card_ids, data.available_answers)
            }));
            return data;
        } catch (error) {
            if (mounted.current && request === version.current) setState(previous => ({ ...previous, loading: false, error: error.message }));
        }
    }, [id, endpoint, navigate]);

    useEffect(() => {
        mounted.current = true;
        sessionId.current = null;
        retained.current = null;
        setState({ items: [], loading: true, error: null, answered_count: 0, correct_count: 0 });
        refresh();
        return () => { mounted.current = false; version.current++; };
    }, [refresh]);

    useUserUpdates(['card.reviewed', 'card.changed', 'deck.changed', 'session.finished'], refresh, id);

    const answer = async (item, rating) => {
        if (busy.current) return false;
        busy.current = true;
        version.current++; // Discard snapshots started before this answer.
        setSaving(true);
        let success = false;
        let snapshot;
        let conflict = false;
        let failure;
        try {
            const res = await fetch(`/api/v1/decks/${id}/study/answer`, {
                method: 'POST', credentials: 'include', headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ card_id: item.id ?? item.card_id, rating, session_id: sessionId.current })
            });
            if (!res.ok) {
                conflict = res.status === 409 || res.status === 404;
                const data = await res.json();
                throw new Error(data.error || 'Не удалось сохранить ответ. Попробуйте снова.');
            }
            if (mode === 'quiz') retained.current = item;
            success = true;
        } catch (error) {
            failure = error.message;
        } finally {
            busy.current = false;
            if (success || conflict) snapshot = await refresh();
            if (failure && mounted.current) setState(previous => ({ ...previous, error: failure }));
            if (mounted.current) setSaving(false);
        }
        return success ? snapshot || true : false;
    };

    const next = async () => {
        const item = retained.current;
        retained.current = null;
        if (item) setState(previous => ({ ...previous, items: previous.items.filter(question => question.card_id !== item.card_id) }));
        await refresh();
    };

    const finish = async () => {
        if (busy.current) return;
        busy.current = true;
        version.current++;
        setSaving(true);
        try {
            if (sessionId.current) {
                const res = await fetch(`/api/v1/decks/${id}/study/finish`, {
                    method: 'POST', credentials: 'include', headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ session_id: sessionId.current })
                });
                if (!res.ok) throw new Error('Не удалось завершить занятие. Попробуйте снова.');
            }
            navigate(`/decks/${id}`);
        } catch (error) {
            if (mounted.current) setState(previous => ({ ...previous, error: error.message }));
        } finally {
            busy.current = false;
            if (mounted.current) setSaving(false);
        }
    };

    return { ...state, saving, answer, next, finish, refresh, retainedId: retained.current?.card_id };
}
