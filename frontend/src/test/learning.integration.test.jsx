import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { act } from 'react';
import { createRoot } from 'react-dom/client';
import { MemoryRouter, Route, Routes } from 'react-router-dom';
import { AuthProvider } from '../context/AuthContext';
import Quiz from '../pages/Quiz';
import Study from '../pages/Study';

const cable = vi.hoisted(() => ({ emit: null, close: vi.fn() }));
vi.mock('../lib/userUpdates', () => ({
    connectUserUpdates: onEvent => {
        cable.emit = onEvent;
        return cable.close;
    }
}));

globalThis.IS_REACT_ACT_ENVIRONMENT = true;

const first = { card_id: 1, word: 'one', correct_answer: 'один', options: ['один', 'два', 'три', 'четыре'] };
const second = { card_id: 2, word: 'two', correct_answer: 'два', options: ['два', 'один', 'три', 'четыре'] };
const json = (body, status = 200) => ({ ok: status < 400, status, json: async () => structuredClone(body) });

describe('learning pages with real hooks, auth context and router', () => {
    let root, container, snapshot, fetchMock, answerResponse;

    beforeEach(() => {
        snapshot = {
            session_id: 10, deck_title: 'Numbers', finished: false, answered_count: 0, correct_count: 0,
            questions: [first, second], existing_card_ids: [1, 2, 3, 4],
            available_answers: ['один', 'два', 'три', 'четыре'],
            cards: [{ id: 1, front: 'one', back: 'один' }, { id: 2, front: 'two', back: 'два' }]
        };
        answerResponse = async options => {
            const { card_id, rating } = JSON.parse(options.body);
            snapshot.questions = snapshot.questions.filter(question => question.card_id !== card_id);
            snapshot.cards = snapshot.cards.filter(card => card.id !== card_id);
            snapshot.answered_count++;
            if (rating !== 'forgot') snapshot.correct_count++;
            return json({});
        };
        fetchMock = vi.fn(async (url, options = {}) => {
            if (url === '/api/v1/current_user') return json({ user: { email: 'one@example.com' } });
            if (url.includes('/study/answer')) return answerResponse(options);
            if (url.includes('/study/finish')) return json({});
            if (url.includes('/quiz')) return json({ ...snapshot, cards: undefined });
            if (url.includes('/study')) return json({ ...snapshot, questions: undefined });
            throw new Error(`Unexpected request: ${url}`);
        });
        vi.stubGlobal('fetch', fetchMock);
        container = document.createElement('div');
        document.body.appendChild(container);
        root = createRoot(container);
    });

    afterEach(async () => {
        await act(async () => root.unmount());
        container.remove();
        vi.unstubAllGlobals();
    });

    async function mount(mode = 'quiz') {
        await act(async () => root.render(
            <AuthProvider>
                <MemoryRouter initialEntries={[mode === 'quiz' ? '/study/1/quiz' : '/study/1']}>
                    <Routes>
                        <Route path="/study/:id/quiz" element={<Quiz />} />
                        <Route path="/study/:id" element={<Study />} />
                        <Route path="/decks/:id" element={<p>Deck page</p>} />
                        <Route path="/decks" element={<p>Deck list</p>} />
                        <Route path="/login" element={<p>Login page</p>} />
                    </Routes>
                </MemoryRouter>
            </AuthProvider>
        ));
    }

    async function emit(type, data = { deck_id: 1 }) {
        await act(async () => {
            cable.emit({ type, data });
            await new Promise(resolve => setTimeout(resolve, 80));
        });
    }

    async function click(text) {
        const button = [...container.querySelectorAll('button')].find(button => button.textContent.trim() === text);
        expect(button, `Button ${text}`).toBeTruthy();
        await act(async () => button.click());
    }

    it('renders loading with null feedback and then an empty queue without crashing', async () => {
        let release;
        const original = fetchMock.getMockImplementation();
        fetchMock.mockImplementation((url, options) => url.includes('/quiz')
            ? new Promise(resolve => { release = resolve; }) : original(url, options));
        await mount();
        expect(container.textContent).toContain('Загрузка...');
        snapshot.questions = [];
        await act(async () => release(json({ ...snapshot, cards: undefined })));
        expect(container.textContent).toContain('На сегодня всё повторено');
    });

    it('saves an answer over HTTP and retains its feedback through a socket refresh until Next', async () => {
        await mount();
        await click('один');
        expect(container.querySelector('.quiz-word-box').textContent).toBe('one');
        expect(container.querySelector('.quiz-option--correct').textContent).toContain('✓');
        expect(container.textContent).toContain('Верно: 1');
        await emit('card.reviewed');
        expect(container.querySelector('.quiz-word-box').textContent).toBe('one');
        expect(container.querySelector('.quiz-option--correct')).toBeTruthy();
        await click('Далее');
        expect(container.querySelector('.quiz-word-box').textContent).toBe('two');
        expect(container.querySelector('.quiz-option--correct')).toBeNull();
        const answers = fetchMock.mock.calls.filter(([url]) => url.endsWith('/study/answer'));
        expect(answers).toHaveLength(1);
        expect(JSON.parse(answers[0][1].body)).toEqual({ card_id: 1, rating: 'good', session_id: 10 });
    });

    it('updates remote reviews and session completion without reloading or creating a new session', async () => {
        await mount();
        snapshot.questions = [second];
        snapshot.answered_count = 1;
        await emit('card.reviewed');
        expect(container.querySelector('.quiz-word-box').textContent).toBe('two');
        snapshot.finished = true;
        snapshot.questions = [];
        await emit('session.finished');
        expect(container.textContent).toContain('Сессия завершена');
        expect(fetchMock.mock.calls.filter(([url]) => url.includes('/quiz')).slice(1).every(([url]) => url.includes('session_id=10'))).toBe(true);
    });

    it('ignores another deck and refreshes once after reconnecting', async () => {
        await mount();
        const count = fetchMock.mock.calls.length;
        await emit('card.changed', { deck_id: 2 });
        expect(fetchMock.mock.calls.length).toBe(count);
        snapshot.questions = [second];
        await emit('connection.restored', {});
        expect(fetchMock.mock.calls.length).toBe(count + 1);
        expect(container.querySelector('.quiz-word-box').textContent).toBe('two');
    });

    it('allows retry after a failed answer without showing false success', async () => {
        await mount();
        const successfulAnswer = answerResponse;
        answerResponse = async () => json({ error: 'Сервер недоступен' }, 503);
        await click('один');
        expect(container.querySelector('[role="alert"]').textContent).toContain('Сервер недоступен');
        expect(container.querySelector('.quiz-option--correct')).toBeNull();
        expect(container.textContent).not.toContain('Далее');
        answerResponse = successfulAnswer;
        await click('один');
        expect(container.querySelector('.quiz-option--correct')).toBeTruthy();
    });

    it('supports keyboard study and blocks duplicate answers while saving', async () => {
        await mount('cards');
        await act(async () => window.dispatchEvent(new KeyboardEvent('keydown', { code: 'Space', key: ' ', bubbles: true })));
        expect(container.querySelector('.flashcard__back').textContent).toBe('один');
        const successfulAnswer = answerResponse;
        let release;
        answerResponse = options => new Promise(resolve => { release = async () => resolve(await successfulAnswer(options)); });
        await act(async () => {
            window.dispatchEvent(new KeyboardEvent('keydown', { key: '3', bubbles: true }));
            window.dispatchEvent(new KeyboardEvent('keydown', { key: '3', bubbles: true }));
        });
        expect(fetchMock.mock.calls.filter(([url]) => url.endsWith('/study/answer'))).toHaveLength(1);
        await act(async () => release());
        expect(container.querySelector('.flashcard__front').textContent).toBe('two');
        expect(container.querySelector('.flashcard__back')).toBeNull();
    });

    it('redirects when the deck is deleted and disconnects on unmount', async () => {
        await mount();
        const original = fetchMock.getMockImplementation();
        fetchMock.mockImplementation((url, options) => url.includes('/quiz') ? json({}, 404) : original(url, options));
        await emit('deck.changed');
        expect(container.textContent).toContain('Deck list');
        await act(async () => root.unmount());
        expect(cable.close).toHaveBeenCalled();
    });
});
