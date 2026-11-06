import { useState, useEffect } from 'react';
import { useParams, Link } from 'react-router-dom';
import Header from '../components/Header.jsx';
import { useLiveStudy } from '../hooks/useLiveStudy';

export default function Study() {
    const { id } = useParams();
    const live = useLiveStudy(id, 'cards');
    const [isFlipped, setIsFlipped] = useState(false);
    const currentCard = live.items[0];
    const currentCardId = currentCard?.id;
    const deckTitle = live.deck_title;
    const total = live.answered_count + live.items.length;
    const progressPercent = total ? live.answered_count / total * 100 : 0;
    const finishSession = live.finish;

    useEffect(() => { setIsFlipped(false); }, [currentCardId]);

    const handleRate = async rating => {
        if (!isFlipped || live.saving || !currentCard) return;
        const snapshot = await live.answer(currentCard, rating);
        if (snapshot) {
            setIsFlipped(false);
            if (snapshot.cards?.length === 0 && !snapshot.finished) await finishSession();
        }
    };

    useEffect(() => {
        const handleKeyDown = event => {
            if (live.loading || live.saving || event.repeat) return;
            if (event.code === 'Space' && currentCard) {
                event.preventDefault();
                setIsFlipped(previous => !previous);
            }
            if (isFlipped && currentCard && ['1', '2', '3', '4'].includes(event.key)) {
                event.preventDefault();
                handleRate(['forgot', 'hard', 'good', 'easy'][Number(event.key) - 1]);
            }
            if (event.key === 'Enter' && !currentCard) finishSession();
        };
        window.addEventListener('keydown', handleKeyDown);
        return () => window.removeEventListener('keydown', handleKeyDown);
    });

    if (live.loading) return <div className="page">Загрузка...</div>;
    if (!currentCard) return (
        <>
            <Header />
            <main className="page">
                <h1 className="page__title">{live.finished ? 'Сессия завершена' : 'На сегодня всё повторено'}</h1>
                <p className="page__subtitle">{live.finished ? 'Занятие завершено в другой вкладке или на другом устройстве.' : 'Новых карточек и карточек к повторению пока нет. Список обновится автоматически, если вы добавите слова.'}</p>
                {live.error && <p role="alert">{live.error}</p>}
                <button onClick={live.refresh} className="btn btn--ghost">Обновить данные</button>
                {live.session_id && !live.finished && <button onClick={finishSession} disabled={live.saving} className="btn">Завершить сессию</button>}
                <Link to={`/decks/${id}`} className="btn btn--ghost">Вернуться в колоду</Link>
            </main>
        </>
    );

    return (
        <>
            <Header />
            <main className="page study-page">

                {live.error && <p role="alert">{live.error}</p>}
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
                            <span className="study-counter__current">{live.answered_count + 1}</span>
                            <span className="study-counter__total">/ {total}</span>
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
                    <button onClick={() => handleRate('forgot')} className="study-btn" disabled={live.saving}>
                        <strong>Забыл</strong> <span>1 день</span>
                    </button>
                    <button onClick={() => handleRate('hard')} className="study-btn" disabled={live.saving}>
                        <strong>Трудно</strong> <span>2 дня</span>
                    </button>
                    <button onClick={() => handleRate('good')} className="study-btn" disabled={live.saving}>
                        <strong>Хорошо</strong> <span>4 дня</span>
                    </button>
                    <button onClick={() => handleRate('easy')} className="study-btn" disabled={live.saving}>
                        <strong>Легко</strong> <span>7 дней</span>
                    </button>
                </div>

                <div style={{ marginTop: '32px' }}>
                    <button onClick={finishSession} disabled={live.saving} className="btn btn--ghost">
                        Завершить сессию
                    </button>
                </div>

            </main>
        </>
    );
}
