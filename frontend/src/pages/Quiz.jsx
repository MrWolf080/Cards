import { useState, useEffect } from 'react';
import { useParams, Link, useNavigate } from 'react-router-dom';
import Header from '../components/Header.jsx';

export default function Quiz() {
    const { id } = useParams();
    const navigate = useNavigate();

    const [deckTitle, setDeckTitle] = useState('');
    const [questions, setQuestions] = useState([]);
    const [currentIndex, setCurrentIndex] = useState(0);
    const [sessionId, setSessionId] = useState(null); // 👈 Добавили ID сессии

    // Состояния для ответа
    const [selectedOption, setSelectedOption] = useState(null);
    const [isAnswered, setIsAnswered] = useState(false);
    const [correctCount, setCorrectCount] = useState(0);
    const [error, setError] = useState(null);
    const [loaded, setLoaded] = useState(false);

    useEffect(() => {
        fetch(`/api/v1/decks/${id}/quiz`, { credentials: 'include' })
            .then(res => res.json())
            .then(data => {
                if (data.error) {
                    setError(data.error);
                } else {
                    setDeckTitle(data.deck_title);
                    setQuestions(data.questions);
                    setSessionId(data.session_id); // 👈 Сохраняем ID сессии
                    setLoaded(true);
                }
            })
            .catch(err => console.error(err));
    }, [id]);

    if (error) {
        return (
            <>
                <Header />
                <div className="page">
                    <h1 className="page__title">Тест недоступен</h1>
                    <p className="page__subtitle">{error}</p>
                    <Link to={`/decks/${id}`} className="btn" style={{ marginTop: '20px' }}>Вернуться в колоду</Link>
                </div>
            </>
        );
    }

    if (!loaded) return <div className="page">Загрузка...</div>;
    if (questions.length === 0) return (
        <>
            <Header />
            <main className="page">
                <h1 className="page__title">На сегодня всё повторено</h1>
                <p className="page__subtitle">Нет карточек, срок которых наступил. Загляните завтра или добавьте слова в колоду.</p>
                <Link to={`/decks/${id}`} className="btn" style={{ marginTop: '20px' }}>Вернуться в колоду</Link>
            </main>
        </>
    );

    const currentQuestion = questions[currentIndex];

    const handleOptionClick = async (option) => {
        if (isAnswered) return; // Блокируем клики после ответа

        setSelectedOption(option);
        setIsAnswered(true);

        const isCorrect = option === currentQuestion.correct_answer;
        if (isCorrect) setCorrectCount(prev => prev + 1);

        // 👇 Отправляем результат на сервер с session_id
        await fetch(`/api/v1/decks/${id}/study/answer`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            credentials: 'include',
            body: JSON.stringify({
                card_id: currentQuestion.card_id,
                rating: isCorrect ? 'good' : 'forgot',
                session_id: sessionId
            })
        });
    };

    const finishQuiz = async () => {
        // 👇 Сообщаем серверу, что тест завершен
        if (sessionId) {
            await fetch(`/api/v1/decks/${id}/study/finish`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                credentials: 'include',
                body: JSON.stringify({ session_id: sessionId })
            });
        }

        // Считаем итоговый результат (учитывая последний клик)
        const finalCorrect = correctCount + (selectedOption === currentQuestion.correct_answer ? 1 : 0);
        alert(`Тест завершен! Правильных ответов: ${finalCorrect} из ${questions.length}`);
        navigate(`/decks/${id}`);
    };

    const handleNext = () => {
        if (currentIndex < questions.length - 1) {
            setCurrentIndex(prev => prev + 1);
            setSelectedOption(null);
            setIsAnswered(false);
        } else {
            finishQuiz();
        }
    };

    return (
        <>
            <Header />
            <main className="page study-page">

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
                            <span className="study-counter__current">{currentIndex + 1}</span>
                            <span className="study-counter__total">/ {questions.length}</span>
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
                                disabled={isAnswered}
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
                        <button onClick={handleNext} className="btn">
                            {currentIndex < questions.length - 1 ? 'Далее' : 'Завершить тест'}
                        </button>
                    </div>
                )}

            </main>
        </>
    );
}