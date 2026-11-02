import { useState, useEffect, useCallback } from 'react';
import { useParams, Link, useNavigate } from 'react-router-dom';
import Header from '../components/Header.jsx';

export default function Study() {
    const { id } = useParams();
    const navigate = useNavigate();

    const [deckTitle, setDeckTitle] = useState('');
    const [cards, setCards] = useState([]);
    const [currentIndex, setCurrentIndex] = useState(0);
    const [isFlipped, setIsFlipped] = useState(false);
    const [loading, setLoading] = useState(true);
    const [sessionId, setSessionId] = useState(null);

    useEffect(() => {
        fetch(`/api/v1/decks/${id}/study`, { credentials: 'include' })
            .then(res => res.json())
            .then(data => {
                setDeckTitle(data.deck_title);
                setCards(data.cards);
                setSessionId(data.session_id); // 👈 Сохраняем ID
                setLoading(false);
            })
    }, [id]);

    const finishSession = async () => {
        if (sessionId) {
            await fetch(`/api/v1/decks/${id}/study/finish`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                credentials: 'include',
                body: JSON.stringify({ session_id: sessionId })
            });
        }
        navigate(`/decks/${id}`);
    };

    // Отправка оценки на сервер
    const handleRate = useCallback(async (rating) => {
        if (!isFlipped) return; // Нельзя оценить, пока не перевернули

        const currentCard = cards[currentIndex];

        // Отправляем запрос (не блокируя UI)
        fetch(`/api/v1/decks/${id}/study/answer`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            credentials: 'include',
            body: JSON.stringify({
                card_id: currentCard.id,
                rating,
                session_id: sessionId // 👈 Передаем ID
            })
        });

        // Переходим к следующей карточке
        if (currentIndex < cards.length - 1) {
            setIsFlipped(false);
            setTimeout(() => setCurrentIndex(prev => prev + 1), 150); // Небольшая задержка для анимации
        } else {
            // Если карточки закончились
            await fetch(`/api/v1/decks/${id}/study/finish`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                credentials: 'include',
                body: JSON.stringify({ session_id: sessionId })
            });
            alert('Сессия завершена!');
            navigate(`/decks/${id}`);
        }
    }, [cards, currentIndex, id, isFlipped, navigate]);

    // Обработка клавиатуры
    useEffect(() => {
        const handleKeyDown = (e) => {
            if (loading || cards.length === 0) return;

            if (e.code === 'Space') {
                e.preventDefault();
                setIsFlipped(prev => !prev);
            }

            if (isFlipped) {
                if (e.key === '1') handleRate('forgot');
                if (e.key === '2') handleRate('hard');
                if (e.key === '3') handleRate('good');
                if (e.key === '4') handleRate('easy');
            }
        };

        window.addEventListener('keydown', handleKeyDown);
        return () => window.removeEventListener('keydown', handleKeyDown);
    }, [isFlipped, handleRate, loading, cards.length]);

    if (loading) return <div className="page">Загрузка...</div>;
    if (cards.length === 0) return (
        <>
            <Header />
            <main className="page">
                <h1 className="page__title">На сегодня всё повторено</h1>
                <p className="page__subtitle">Нет карточек, срок которых наступил. Загляните завтра или добавьте слова в колоду.</p>
                <Link to={`/decks/${id}`} className="btn" style={{ marginTop: '20px' }}>Вернуться в колоду</Link>
            </main>
        </>
    );

    const currentCard = cards[currentIndex];
    const progressPercent = ((currentIndex) / cards.length) * 100;

    return (
        <>
            <Header />
            <main className="page study-page">

                {/* Верхняя панель */}
                <header className="study-header">
                    <div>
                        <h1 className="page__title" style={{ fontSize: '1.8rem', marginBottom: '4px' }}>Изучение</h1>
                        <p className="page__subtitle">Нажмите на карточку или пробел, чтобы увидеть перевод.</p>

                        <div className="study-tabs">
                            <Link to={`/study/${id}`} className="study-tab study-tab--active">Карточки</Link>
                            <Link to={`/study/${id}/quiz`} className="study-tab">Тест</Link>
                        </div>
                    </div>

                    <div className="study-counter">
                        <div className="study-counter__nums">
                            <span className="study-counter__current">{currentIndex + 1}</span>
                            <span className="study-counter__total">/ {cards.length}</span>
                        </div>
                        <div className="study-counter__deck">{deckTitle}</div>
                    </div>
                </header>

                {/* Прогресс-бар */}
                <div className="progress" style={{ margin: '24px 0 32px', height: '6px' }}>
                    <div className="progress__fill" style={{ width: `${progressPercent}%` }}></div>
                </div>

                {/* Сама карточка */}
                <div
                    className={`flashcard ${isFlipped ? 'flashcard--flipped' : ''}`}
                    onClick={() => setIsFlipped(!isFlipped)}
                >
                    <div className="flashcard__front">
                        {currentCard.front}
                    </div>
                    {isFlipped && (
                        <div className="flashcard__back">
                            {currentCard.back}
                        </div>
                    )}
                </div>

                {/* Кнопки оценки (появляются только после переворота) */}
                <div className={`study-actions ${isFlipped ? 'study-actions--visible' : ''}`}>
                    <button onClick={() => handleRate('forgot')} className="study-btn">
                        <strong>Забыл</strong> <span>1 день</span>
                    </button>
                    <button onClick={() => handleRate('hard')} className="study-btn">
                        <strong>Трудно</strong> <span>2 дня</span>
                    </button>
                    <button onClick={() => handleRate('good')} className="study-btn">
                        <strong>Хорошо</strong> <span>4 дня</span>
                    </button>
                    <button onClick={() => handleRate('easy')} className="study-btn">
                        <strong>Легко</strong> <span>7 дней</span>
                    </button>
                </div>

                <div style={{ marginTop: '32px' }}>
                    <button onClick={finishSession} className="btn btn--ghost">
                        Завершить сессию
                    </button>
                </div>

            </main>
        </>
    );
}