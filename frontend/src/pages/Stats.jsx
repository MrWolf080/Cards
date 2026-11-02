import { useState, useEffect } from 'react';
import Header from '../components/Header.jsx';

export default function Stats() {
    const [data, setData] = useState(null);

    useEffect(() => {
        fetch('/api/v1/stats', { credentials: 'include' })
            .then(res => res.json())
            .then(data => setData(data))
            .catch(err => console.error(err));
    }, []);

    if (!data) return <div className="page">Загрузка...</div>;

    // Считаем процент выполнения дневной цели
    const goalPercent = Math.min((data.today_answers / data.daily_goal) * 100, 100);

    return (
        <>
            <Header />
            <main className="page">
                <header className="page__header">
                    <h1 className="page__title">Статистика</h1>
                    <p className="page__subtitle">Ваш прогресс и история сессий.</p>
                </header>

                {/* Верхний ряд карточек */}
                <div className="metrics metrics--3">
                    <div className="metric">
                        <p className="metric__label">Точность за неделю</p>
                        <p className="metric__value">{data.accuracy}%</p>
                        <div className="progress" style={{ marginTop: '16px', height: '6px' }}>
                            <div className="progress__fill" style={{ width: `${data.accuracy}%` }}></div>
                        </div>
                    </div>

                    <div className="metric">
                        <p className="metric__label">Текущая серия</p>
                        <p className="metric__value">{data.streak} дней</p>
                    </div>

                    <div className="metric">
                        <p className="metric__label">Цель на сегодня</p>
                        <p className="metric__value">
                            {data.today_answers} <span style={{ color: '#ccc', fontSize: '1.2rem' }}>из {data.daily_goal}</span>
                        </p>
                        <div className="progress" style={{ marginTop: '16px', height: '6px' }}>
                            <div className="progress__fill" style={{ width: `${goalPercent}%` }}></div>
                        </div>
                    </div>
                </div>

                {/* Таблица истории */}
                <div className="card card--flush" style={{ marginTop: '24px' }}>
                    <h3 className="metric__label" style={{ margin: '24px 24px 8px', fontWeight: 'bold', color: '#111' }}>
                        История сессий
                    </h3>
                    <table className="table">
                        <thead>
                        <tr>
                            <th>Дата</th>
                            <th>Колода</th>
                            <th>Режим</th>
                            <th>Верно</th>
                            <th>Результат</th>
                        </tr>
                        </thead>
                        <tbody>
                        {data.history.map((session) => (
                            <tr key={session.id}>
                                <td>{session.date}</td>
                                <td>{session.deck_title}</td>
                                <td>{session.mode}</td>
                                <td>{session.correct} из {session.total}</td>
                                <td>{session.percent}%</td>
                            </tr>
                        ))}
                        {data.history.length === 0 && (
                            <tr>
                                <td colSpan="5" style={{ textAlign: 'center', color: '#888', padding: '40px' }}>
                                    У вас пока нет завершенных сессий.
                                </td>
                            </tr>
                        )}
                        </tbody>
                    </table>
                </div>
            </main>
        </>
    );
}