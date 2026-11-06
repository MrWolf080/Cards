import { useState, useEffect } from 'react';
import { useUserUpdates } from '../hooks/useUserUpdates';
import { Link, useNavigate } from 'react-router-dom';
import Header from '../components/Header'; // Твой компонент шапки

export default function Decks() {
    const [decks, setDecks] = useState([]);
    const [loading, setLoading] = useState(true);

    // Состояние для формы создания
    const [showForm, setShowForm] = useState(false);
    const [newTitle, setNewTitle] = useState('');
    const [newDirection, setNewDirection] = useState('en_ru');

    const navigate = useNavigate();

    // Загрузка колод при монтировании
    const fetchDecks = () => {
        fetch('/api/v1/decks', { credentials: 'include' })
            .then(res => res.json())
            .then(data => {
                setDecks(data);
                setLoading(false);
            })
            .catch(err => {
                console.error("Ошибка загрузки:", err);
                setLoading(false);
            });
    };

    useEffect(() => {
        fetchDecks();
    }, []);

    useUserUpdates(['card.reviewed', 'card.changed', 'deck.changed'], fetchDecks);

    // Создание новой колоды
    const handleCreateDeck = async (e) => {
        e.preventDefault();
        const res = await fetch('/api/v1/decks', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            credentials: 'include',
            body: JSON.stringify({ deck: { title: newTitle, direction: newDirection } })
        });

        if (res.ok) {
            setNewTitle('');
            setShowForm(false);
            fetchDecks(); // Перезапрашиваем список
        } else {
            alert("Ошибка при создании колоды");
        }
    };

    const handleDelete = async (deckId) => {
        // Спрашиваем подтверждение у пользователя
        if (!window.confirm("Вы уверены, что хотите удалить колоду? Все карточки и прогресс будут потеряны.")) {
            return;
        }

        try {
            const res = await fetch(`/api/v1/decks/${deckId}`, {
                method: 'DELETE',
                credentials: 'include'
            });

            if (res.ok) {
                // Убираем удаленную колоду из состояния React (список обновится мгновенно)
                setDecks(decks.filter(deck => deck.id !== deckId));
            } else {
                alert("Не удалось удалить колоду");
            }
        } catch (error) {
            console.error("Ошибка удаления:", error);
        }
    };

    return (
        <>
            <Header />
            <main className="page">
                <header className="page__header" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
                    <div>
                        <h1 className="page__title">Мои колоды</h1>
                        <p className="page__subtitle">Выберите колоду, чтобы учить слова или пополнить колоду.</p>
                    </div>
                    <button onClick={() => setShowForm(!showForm)} className="btn">
                        {showForm ? 'Отмена' : 'Создать колоду'}
                    </button>
                </header>

                {/* Инлайн-форма создания колоды */}
                {showForm && (
                    <form onSubmit={handleCreateDeck} className="card" style={{ marginBottom: '24px', display: 'flex', gap: '16px', alignItems: 'flex-end' }}>
                        <div style={{ flex: 1 }}>
                            <label className="auth__label" style={{ display: 'block', marginBottom: '8px' }}>Название</label>
                            <input
                                type="text"
                                className="auth__input"
                                value={newTitle}
                                onChange={e => setNewTitle(e.target.value)}
                                placeholder="Например: English B1"
                                required
                            />
                        </div>
                        <div>
                            <label className="auth__label" style={{ display: 'block', marginBottom: '8px' }}>Направление</label>
                            <select className="auth__input" value={newDirection} onChange={e => setNewDirection(e.target.value)}>
                                <option value="en_ru">Английский → Русский</option>
                                <option value="ru_en">Русский → Английский</option>
                            </select>
                        </div>
                        <button type="submit" className="btn">Сохранить</button>
                    </form>
                )}

                {/* Список колод */}
                {loading ? (
                    <p className="page__subtitle">Загрузка...</p>
                ) : decks.length === 0 ? (
                    <div className="card" style={{ textAlign: 'center', padding: '48px' }}>
                        <p style={{ color: '#666', margin: 0 }}>У вас пока нет колод. Создайте первую!</p>
                    </div>
                ) : (
                    <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
                        {decks.map(deck => {
                            // Считаем процент выученных слов для прогресс-бара
                            const progressPercent = deck.total_cards > 0
                                ? Math.round((deck.learned_cards / deck.total_cards) * 100)
                                : 0;

                            return (
                                <div key={deck.id} className="deck-card">
                                    <div className="deck-card__header">
                                        <h3 className="deck-card__title">
                                            {deck.title} <span className="deck-card__direction">{deck.direction}</span>
                                        </h3>
                                    </div>

                                    <div className="progress" style={{ margin: '16px 0 8px' }}>
                                        <div className="progress__fill" style={{ width: `${progressPercent}%` }}></div>
                                    </div>

                                    <div className="deck-card__footer">
                    <span className="deck-card__stats">
                      {deck.learned_cards} из {deck.total_cards} выучено · к повторению: {deck.to_review}
                    </span>
                                        <div className="deck-card__actions">
                                            {/* 👇 Новая кнопка удаления */}
                                            <button
                                                onClick={() => handleDelete(deck.id)}
                                                className="btn btn--ghost"
                                                style={{ color: '#dc2626', borderColor: 'transparent' }}
                                                title="Удалить колоду"
                                            >
                                                Удалить
                                            </button>

                                            <Link to={`/decks/${deck.id}`} className="btn btn--ghost">Открыть</Link>
                                            <Link to={`/study/${deck.id}`} className="btn">Учить</Link>
                                        </div>
                                    </div>
                                </div>
                            );
                        })}
                    </div>
                )}
            </main>
        </>
    );
}
