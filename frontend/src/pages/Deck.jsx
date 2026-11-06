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
    const [search, setSearch] = useState('');

    // 1. Функция для запроса подборки (возвращает данные)
    const fetchSuggestionsData = async (count = 5, excludeIds = []) => {
        let url = `/api/v1/decks/${id}/suggestions?count=${count}`;
        excludeIds.forEach(exId => {
            url += `&exclude[]=${exId}`;
        });

        try {
            const res = await fetch(url, { credentials: 'include' });
            if (res.ok) {
                return await res.json();
            }
            return [];
        } catch (err) {
            console.error("Ошибка загрузки подборки:", err);
            return [];
        }
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

    // 3. Кнопка "Обновить все"
    const handleRefreshAll = async () => {
        const newWords = await fetchSuggestionsData(5, []);
        setSuggestions(newWords);
    };

    // 4. Кнопка "Другое" (замена одного слова)
    const handleReplace = async (index) => {
        const currentIds = suggestions.map(s => s.id);
        const newWords = await fetchSuggestionsData(1, currentIds);

        if (newWords.length > 0) {
            const newSuggestions = [...suggestions];
            newSuggestions[index] = newWords[0];
            setSuggestions(newSuggestions);
        } else {
            alert("В словаре больше нет новых слов.");
        }
    };

    // 5. Добавление карточки
    // Добавление карточки (теперь принимает индекс слова в подборке)
    const handleAdd = async (entryId, index) => {
        // 1. Отправляем запрос на добавление карточки в колоду
        await fetch(`/api/v1/decks/${id}/cards`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            credentials: 'include',
            body: JSON.stringify({ dictionary_entry_id: entryId })
        });

        // 2. Обновляем список карточек слева
        const cardsRes = await fetch(`/api/v1/decks/${id}/cards`, { credentials: 'include' });
        setCards(await cardsRes.json());

        // 3. Заменяем только одно слово в подборке справа
        const currentIds = suggestions.map(s => s.id);
        const newWords = await fetchSuggestionsData(1, currentIds);

        if (newWords.length > 0) {
            const newSuggestions = [...suggestions];
            newSuggestions[index] = newWords[0]; // Меняем слово по индексу
            setSuggestions(newSuggestions);
        }
    };

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
                                    <td>{card.front}</td>
                                    <td>{card.back}</td>
                                    <td>{formatStatus(card.status)}</td>
                                    <td>{formatNextReview(card.next_review)}</td>
                                    <td style={{ textAlign: 'right' }}>
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
                        <p className="page__subtitle" style={{ marginBottom: '20px', fontSize: '0.8rem' }}>Случайные слова из словаря</p>

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
                                        <div className="suggestion-actions">
                                            <button onClick={() => handleAdd(entry.id, index)} className="btn">Добавить</button>
                                            <button onClick={() => handleReplace(index)} className="btn btn--ghost">Другое</button>
                                        </div>
                                    </div>
                                );
                            })}
                        </div>

                        <button onClick={handleRefreshAll} className="btn btn--ghost" style={{ width: '100%', marginTop: '16px' }}>
                            Обновить все
                        </button>
                    </div>
                </div>
            </main>
        </>
    );
}
