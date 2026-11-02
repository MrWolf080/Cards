import { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import Header from '../components/Header.jsx';

export default function Dashboard() {
    const [data, setData] = useState(null);
    const [loading, setLoading] = useState(true);

    useEffect(() => {
        fetch('/api/v1/dashboard', { credentials: 'include' })
            .then(res => res.json())
            .then(data => {
                setData(data);
                setLoading(false);
            })
            .catch(err => console.error(err));
    }, []);

    if (loading) return <div className="page">Загрузка...</div>;

    // Находим максимальное значение для графика, чтобы рассчитать высоту столбцов
    const maxChartValue = Math.max(...data.chart_data.map(d => d.count), 1);

    return (
        <>
            <Header />
            <main className="page">
                <header className="page__header" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
                    <div>
                        <h1 className="page__title">Панель</h1>
                        <p className="page__subtitle">Общий обзор вашего обучения и активности.</p>
                    </div>
                    <Link to="/decks" className="btn">Начать повторение</Link>
                </header>

                {/* Сетка метрик */}
                <div className="metrics">
                    <div className="metric">
                        <p className="metric__label">К повторению сегодня</p>
                        <p className="metric__value">{data.cards_to_review}</p>
                        <span className="metric__sub">карточки</span>
                    </div>
                    <div className="metric">
                        <p className="metric__label">Выучено слов</p>
                        <p className="metric__value">{data.learned_words}</p>

                        {/* 👇 Динамический вывод прироста */}
                        {data.learned_delta > 0 ? (
                            <span className="metric__sub" style={{ color: '#16a34a' }}>
                ▲ +{data.learned_delta} за 7 дней
              </span>
                        ) : data.learned_delta < 0 ? (
                            <span className="metric__sub" style={{ color: '#dc2626' }}>
                ▼ {data.learned_delta} за 7 дней
              </span>
                        ) : (
                            <span className="metric__sub">0 за 7 дней</span>
                        )}
                    </div>
                    <div className="metric">
                        <p className="metric__label">Серия</p>
                        <p className="metric__value">{data.streak} дней</p>
                        <span className="metric__sub">подряд</span>
                    </div>
                    <div className="metric">
                        <p className="metric__label">Точность</p>
                        <p className="metric__value">{data.accuracy}%</p>
                        <span className="metric__sub">за 7 дней</span>
                    </div>
                </div>

                <div className="grid-2">
                    {/* График */}
                    <div className="card">
                        <h3 className="metric__label" style={{ marginBottom: '24px', fontWeight: 'bold' }}>Активность за 7 дней</h3>

                        <div className="bar-chart">
                            {data.chart_data.map((item, index) => {
                                // Считаем высоту в процентах (минимум 5%, чтобы столбик был виден)
                                const height = Math.max((item.count / maxChartValue) * 100, 5);

                                return (
                                    <div key={index} className="bar-chart__col">
                                        <div className="bar-chart__bar" style={{ height: `${height}%` }}></div>
                                        <span className="bar-chart__label">{item.day}</span>
                                    </div>
                                );
                            })}
                        </div>
                    </div>

                    {/* Последние сессии */}
                    <div className="card" style={{ padding: 0 }}>
                        <h3 className="metric__label" style={{ margin: '24px 24px 16px', fontWeight: 'bold' }}>Последние сессии</h3>

                        <table className="table" style={{ marginTop: 0 }}>
                            <thead>
                            <tr>
                                <th>Дата</th>
                                <th>Колода</th>
                                <th>Карточек</th>
                                <th>Верно</th>
                            </tr>
                            </thead>
                            <tbody>
                            {data.recent_sessions.map((session, i) => (
                                <tr key={i}>
                                    <td>{session.date}</td>
                                    <td>{session.deck_title}</td>
                                    <td>{session.total}</td>
                                    <td>{session.correct}</td>
                                </tr>
                            ))}
                            {data.recent_sessions.length === 0 && (
                                <tr>
                                    <td colSpan="4" style={{ textAlign: 'center', color: '#888', padding: '20px' }}>
                                        У вас еще нет завершенных сессий.
                                    </td>
                                </tr>
                            )}
                            </tbody>
                        </table>
                    </div>
                </div>
            </main>
        </>
    );
}