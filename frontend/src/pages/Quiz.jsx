import { useState, useEffect } from 'react';
import { useParams, Link } from 'react-router-dom';
import Header from '../components/Header.jsx';
import { useLiveStudy } from '../hooks/useLiveStudy';

export default function Quiz() {
    const { id } = useParams();
    const live = useLiveStudy(id, 'quiz');
    const [feedback, setFeedback] = useState(null);
    const currentQuestion = live.items[0];
    const selectedOption = feedback && currentQuestion && feedback.cardId === currentQuestion.card_id ? feedback.option : null;
    const isAnswered = !!currentQuestion && live.retainedId === currentQuestion.card_id;
    const correctCount = live.correct_count;
    const total = live.answered_count + live.items.length - (isAnswered ? 1 : 0);

    const handleOptionClick = async option => {
        if (isAnswered || live.saving || !currentQuestion) return;
        const question = currentQuestion;
        if (await live.answer(question, option === question.correct_answer ? 'good' : 'forgot')) {
            setFeedback({ cardId: question.card_id, option });
        }
    };

    const handleNext = async () => {
        if (live.saving || !isAnswered) return;
        if (live.items.length === 1) await live.finish();
        else { setFeedback(null); await live.next(); }
    };

    useEffect(() => {
        const handleKeyDown = event => {
            if (live.loading || live.saving || event.repeat) return;
            if (event.key === 'Enter' && isAnswered) { event.preventDefault(); handleNext(); }
            if (!isAnswered && currentQuestion && ['1', '2', '3', '4'].includes(event.key)) {
                const option = currentQuestion.options[Number(event.key) - 1];
                if (option !== undefined) { event.preventDefault(); handleOptionClick(option); }
            }
        };
        window.addEventListener('keydown', handleKeyDown);
        return () => window.removeEventListener('keydown', handleKeyDown);
    });

    if (live.loading) return <div className="page">Загрузка...</div>;
    if (!currentQuestion) return (
        <>
            <Header />
            <main className="page">
                <h1 className="page__title">{live.finished ? 'Сессия завершена' : live.error ? 'Тест недоступен' : 'На сегодня всё повторено'}</h1>
                <p className="page__subtitle">{live.finished ? 'Занятие завершено в другой вкладке или на другом устройстве.' : 'Список обновляется автоматически при изменении колоды.'}</p>
                {live.error && <p role="alert">{live.error}</p>}
                <button onClick={live.refresh} className="btn btn--ghost">Обновить данные</button>
                {live.session_id && !live.finished && <button onClick={live.finish} disabled={live.saving} className="btn">Завершить тест</button>}
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
                        <h1 className="page__title" style={{ fontSize: '1.8rem', marginBottom: '4px' }}>Тест</h1>
                        <p className="page__subtitle">Выберите правильный перевод слова.</p>

                        <div className="study-tabs">
                            <Link to={`/study/${id}`} className="study-tab">Карточки</Link>
                            <Link to={`/study/${id}/quiz`} className="study-tab study-tab--active">Тест</Link>
                        </div>
                    </div>

                    <div className="study-counter">
                        <div className="study-counter__nums">
                            <span className="study-counter__current">{live.answered_count + (isAnswered ? 0 : 1)}</span>
                            <span className="study-counter__total">/ {total}</span>
                        </div>
                        <div className="study-counter__deck">Верно: {correctCount}</div>
                    </div>
                </header>

                {/* Блок вопроса */}
                <div className="quiz-word-box">
                    {currentQuestion.word}
                </div>

                {/* Варианты ответов */}
                <div className="quiz-options">
                    {currentQuestion.options.map((option, index) => {
                        const isCorrect = option === currentQuestion.correct_answer;
                        const isSelected = option === selectedOption;

                        // Определяем класс для кнопки в зависимости от состояния
                        let btnClass = "quiz-option";
                        if (isAnswered) {
                            if (isCorrect) btnClass += " quiz-option--correct";
                            else if (isSelected) btnClass += " quiz-option--incorrect";
                        }

                        return (
                            <button
                                key={index}
                                className={btnClass}
                                onClick={() => handleOptionClick(option)}
                                disabled={isAnswered || live.saving}
                            >
                                {isAnswered && isCorrect && <span className="quiz-icon">✓</span>}
                                {isAnswered && isSelected && !isCorrect && <span className="quiz-icon">✕</span>}
                                {option}
                            </button>
                        );
                    })}
                </div>

                {/* Кнопка Далее (появляется после ответа) */}
                {isAnswered && (
                    <div style={{ marginTop: '24px' }}>
                        <button onClick={handleNext} disabled={live.saving} className="btn">
                            {live.items.length > 1 ? 'Далее' : 'Завершить тест'}
                        </button>
                    </div>
                )}

            </main>
        </>
    );
}
