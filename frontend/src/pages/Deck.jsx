import { useState, useEffect } from 'react';
import { useParams, Link, useNavigate } from 'react-router-dom';
import { useUserUpdates } from '../hooks/useUserUpdates';
import Header from '../components/Header.jsx';

export default function Deck() {
    const { id } = useParams();
    const navigate = useNavigate();
    const [deck, setDeck] = useState(null);
    const [cards, setCards] = useState([]);
    const [suggestions, setSuggestions] = useState([]);
    const [updatingSuggestions, setUpdatingSuggestions] = useState(false);
    const [suggestionError, setSuggestionError] = useState('');
    const [search, setSearch] = useState('');
    const [draft, setDraft] = useState(null);
    const [saving, setSaving] = useState(false);
    const [formError, setFormError] = useState('');

    const openEditor = (card) => {
        setFormError('');
        setDraft({ id: card?.id, front: card?.front ?? '', back: card?.back ?? '', example: card?.example ?? '' });
    };

    const saveCard = async (event) => {
        event.preventDefault();
        setSaving(true);
        setFormError('');
        const { id: cardId, front, back, example } = draft;
        const path = `/api/v1/decks/${id}/cards`;
        try {
            const response = await fetch(cardId ? `${path}/${cardId}` : path, {
                method: cardId ? 'PATCH' : 'POST',
                headers: { 'Content-Type': 'application/json' },
                credentials: 'include',
                body: JSON.stringify({ card: { front, back, example } })
            });
            if (!response.ok) {
                const data = await response.json().catch(() => ({}));
                throw new Error(data.errors?.join('. ') || 'Не удалось сохранить карточку.');
            }
            setDraft(null);
            const updated = await fetch(path, { credentials: 'include' });
            if (!updated.ok) throw new Error('Карточка сохранена, но не удалось обновить список.');
            setCards(await updated.json());
        } catch (error) {
            setFormError(error.message);
        } finally {
            setSaving(false);
        }
    };

    // 1. Функция для запроса подборки (возвращает данные)
    const fetchSuggestionsData = async (count = 5, excludeIds = [], skippedIds = []) => {
        let url = `/api/v1/decks/${id}/suggestions?count=${count}`;
        if (skippedIds.length) url = url.replace('/suggestions?', '/suggestions/skip?');
        excludeIds.forEach(exId => {
            url += `&exclude[]=${exId}`;
        });

        const options = { credentials: 'include' };
        if (skippedIds.length) Object.assign(options, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ ids: skippedIds })
        });
        const res = await fetch(url, options);
        if (!res.ok) throw new Error('Не удалось обновить подборку.');
        return res.json();
    };

    // 2. Начальная загрузка страницы
    const fetchData = async () => {
        try {
            // Инфо о колоде
            const deckRes = await fetch(`/api/v1/decks/${id}`, { credentials: 'include' });
            setDeck(await deckRes.json());

            // Карточки
            const cardsRes = await fetch(`/api/v1/decks/${id}/cards`, { credentials: 'include' });
            setCards(await cardsRes.json());

            // Подборка слов (сохраняем в стейт!)
            const words = await fetchSuggestionsData(5, []);
            setSuggestions(words);
        } catch (err) {
            console.error(err);
        }
    };

    useEffect(() => {
        fetchData();
        setDraft(null);
        setFormError('');
    }, [id]);

    useUserUpdates(['card.changed', 'card.reviewed', 'deck.changed'], async () => {
        const deckRes = await fetch(`/api/v1/decks/${id}`, { credentials: 'include' });
        if (deckRes.status === 404) { navigate('/decks', { replace: true }); return; }
        if (!deckRes.ok) return;
        const cardsRes = await fetch(`/api/v1/decks/${id}/cards`, { credentials: 'include' });
        if (!cardsRes.ok) return;
        setDeck(await deckRes.json());
        setCards(await cardsRes.json());
    }, id);

    const updateSuggestions = async (action) => {
        setUpdatingSuggestions(true);
        setSuggestionError('');
        try {
            await action();
        } catch (error) {
            setSuggestionError(error.message);
        } finally {
            setUpdatingSuggestions(false);
        }
    };

    const handleRefreshAll = () => updateSuggestions(async () => {
        setSuggestions(await fetchSuggestionsData(5, [], suggestions.map(entry => entry.id)));
    });

    const replaceSuggestion = async (index, skippedIds = []) => {
        const replacement = await fetchSuggestionsData(1, suggestions.map(entry => entry.id), skippedIds);
        setSuggestions(suggestions.flatMap((entry, position) => position === index ? replacement : [entry]));
    };

    const handleReplace = (index) => updateSuggestions(() => replaceSuggestion(index, [suggestions[index].id]));

    const resetViews = () => updateSuggestions(async () => {
        const response = await fetch('/api/v1/dictionary/views', { method: 'DELETE', credentials: 'include' });
        if (!response.ok) throw new Error('Не удалось сбросить просмотренные слова.');
        setSuggestions(await fetchSuggestionsData());
    });

    const handleAdd = (entryId, index) => updateSuggestions(async () => {
        const response = await fetch(`/api/v1/decks/${id}/cards`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            credentials: 'include',
            body: JSON.stringify({ dictionary_entry_id: entryId })
        });
        if (!response.ok) throw new Error('Не удалось добавить карточку.');

        // 2. Обновляем список карточек слева
        const cardsRes = await fetch(`/api/v1/decks/${id}/cards`, { credentials: 'include' });
        setCards(await cardsRes.json());

        // 3. Заменяем только одно слово в подборке справа
        await replaceSuggestion(index);
    });

    // 6. Удаление карточки
    const handleDeleteCard = async (cardId) => {
        if (!window.confirm("Удалить карточку?")) return;
        await fetch(`/api/v1/decks/${id}/cards/${cardId}`, { method: 'DELETE', credentials: 'include' });
        setCards(cards.filter(c => c.id !== cardId));
    };

    if (!deck) return <div className="page">Загрузка...</div>;

    // Фильтрация карточек для поиска
    const filteredCards = cards.filter(c =>
        c.front.toLowerCase().includes(search.toLowerCase()) ||
        c.back.toLowerCase().includes(search.toLowerCase())
    );

    const formatStatus = (status) => {
        if (status === 'learned') return 'Выучено';
        if (status === 'learning') return 'Изучается';
        return 'Новое';
    };

    // Функция для расчета дней до следующего показа
    const formatNextReview = (dateString) => {
        if (!dateString) return '—';                       // карточку ещё не оценивали

        // Разбираем 'YYYY-MM-DD' вручную: new Date(строка) читает её как UTC и может сдвинуть день
        const [y, m, d] = dateString.split('-').map(Number);
        const next = new Date(y, m - 1, d);
        const today = new Date();
        today.setHours(0, 0, 0, 0);

        const diff = Math.round((next - today) / (1000 * 60 * 60 * 24));
        if (diff < 0) return 'Просрочено';
        if (diff === 0) return 'Сегодня';
        if (diff === 1) return 'Завтра';
        return `Через ${diff} дн.`;
    };

    const isRuEn = deck.direction === 'RU → EN';

    return (
        <>
            <Header />
            <main className="page">
                <header className="page__header deck-header">
                    <div>
                        <h1 className="page__title">{deck.title}</h1>
                        <p className="page__subtitle">
                            {deck.direction} · {cards.length} карточек · к повторению сегодня: {deck.to_review || 0}
                        </p>
                    </div>
                    <Link to={`/study/${deck.id}`} className="btn">Учить колоду</Link>
                </header>

                <button type="button" className="btn btn--ghost" onClick={() => openEditor()} disabled={saving}>
                    Добавить свою карточку
                </button>
                {formError && <p role="alert">{formError}</p>}
                {draft && (
                    <form onSubmit={saveCard} className="card profile-form" style={{ margin: '16px 0' }}>
                        <h2>{draft.id ? 'Изменить карточку' : 'Новая карточка'}</h2>
                        {[
                            ['front', `Слово (${isRuEn ? 'RU' : 'EN'})`],
                            ['back', `Перевод (${isRuEn ? 'EN' : 'RU'})`],
                            ['example', 'Пример использования']
                        ].map(([field, label]) => (
                            <div className="auth__field" key={field}>
                                <label className="auth__label" htmlFor={`card-${field}`}>{label}</label>
                                <input id={`card-${field}`} className="auth__input" value={draft[field]}
                                    required={field !== 'example'} disabled={saving}
                                    onChange={event => setDraft({ ...draft, [field]: event.target.value })} />
                            </div>
                        ))}
                        <button type="submit" className="btn" disabled={saving}>Сохранить карточку</button>{' '}
                        <button type="button" className="btn btn--ghost" disabled={saving} onClick={() => { setDraft(null); setFormError(''); }}>Отмена</button>
                    </form>
                )}
                <div className="deck-layout">
                    {/* ЛЕВАЯ КОЛОНКА: Карточки */}
                    <div className="deck-main card">
                        <input
                            type="text"
                            placeholder="Поиск по слову"
                            className="search-input"
                            value={search}
                            onChange={e => setSearch(e.target.value)}
                        />

                        <table className="table">
                            <thead>
                            <tr>
                                <th>Слово</th>
                                <th>Перевод</th>
                                <th>Статус</th>
                                <th>След. показ</th>
                                <th></th>
                            </tr>
                            </thead>
                            <tbody>
                            {filteredCards.map(card => (
                                <tr key={card.id}>
                                    <td>{card.front}{card.example && <div className="page__subtitle">{card.example}</div>}</td>
                                    <td>{card.back}</td>
                                    <td>{formatStatus(card.status)}</td>
                                    <td>{formatNextReview(card.next_review)}</td>
                                    <td style={{ textAlign: 'right' }}>
                                        <button onClick={() => openEditor(card)} disabled={saving} className="btn btn--ghost">Изменить</button>{' '}
                                        <button onClick={() => handleDeleteCard(card.id)} className="link-danger">Удалить</button>
                                    </td>
                                </tr>
                            ))}
                            {filteredCards.length === 0 && (
                                <tr>
                                    <td colSpan="5" style={{ textAlign: 'center', color: '#888', padding: '40px' }}>
                                        {search ? 'Ничего не найдено' : 'В колоде пока нет карточек. Добавьте слова из подборки справа.'}
                                    </td>
                                </tr>
                            )}
                            </tbody>
                        </table>
                    </div>

                    {/* ПРАВАЯ КОЛОНКА: Подбор слов */}
                    <div className="deck-sidebar card">
                        <h3 className="sidebar-title">Подбор слов</h3>
                        <p className="page__subtitle">Популярные слова из словаря</p>
                        <button type="button" onClick={resetViews} disabled={updatingSuggestions} className="btn btn--ghost">Сбросить просмотренные слова</button>
                        {suggestionError && <p role="alert">{suggestionError}</p>}
                        {!suggestions.length && !updatingSuggestions && <p>Нет доступных слов для подбора.</p>}

                        <div className="suggestions-list">
                            {suggestions.map((entry, index) => {
                                // 👇 Выбираем правильное слово для показа
                                const displayWord = isRuEn ? entry.ru : entry.en;
                                const displayTrans = isRuEn ? entry.en : entry.ru;

                                return (
                                    <div key={`${entry.id}-${index}`} className="suggestion-item">
                                        <div className="suggestion-word">
                                            <strong>{displayWord}</strong> <span className="suggestion-pos">{entry.part_of_speech}</span>
                                        </div>
                                        <div className="suggestion-trans">{displayTrans}</div>
                                        {entry.example && <p className="page__subtitle">{entry.example}</p>}
                                        <div className="suggestion-actions">
                                            <button onClick={() => handleAdd(entry.id, index)} disabled={updatingSuggestions} className="btn">Добавить</button>
                                            <button onClick={() => handleReplace(index)} disabled={updatingSuggestions} className="btn btn--ghost">Обновить</button>
                                        </div>
                                    </div>
                                );
                            })}
                        </div>

                        <button onClick={handleRefreshAll} disabled={updatingSuggestions} className="btn btn--ghost" style={{ width: '100%', marginTop: '16px' }}>
                            Обновить все
                        </button>
                    </div>
                </div>
            </main>
        </>
    );
}
