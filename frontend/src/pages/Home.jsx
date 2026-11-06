import { Link, useNavigate, Navigate } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';

export default function Home() {
    const { user, logout } = useAuth();
    const navigate = useNavigate();
    // Если пользователь уже вошел, редиректим на панель
    if (user) return <Navigate to="/dashboard" replace />;

    const handleLogout = async () => {
        try {
            // Отправляем DELETE запрос в Rails API
            await fetch('/api/v1/session', {
                method: 'DELETE',
                credentials: 'include'
            });
            logout(); // Очищаем пользователя в React
            navigate('/'); // Перенаправляем на главную
        } catch (error) {
            console.error('Ошибка при выходе', error);
        }
    };

    return (
        <div className="landing">
            <header className="landing__header">
                <span className="landing__logo">К</span>
                <nav className="landing__nav">
                    {user ? (
                        // Если пользователь авторизован
                        <>
                            <span className="landing__user">{user.email}</span>
                            <button onClick={handleLogout} className="landing__btn landing__btn--ghost">
                                Выйти
                            </button>
                        </>
                    ) : (
                        // Если гость
                        <>
                            <Link to="/login" className="landing__link">Войти</Link>
                            <Link to="/signup" className="landing__btn">Регистрация</Link>
                        </>
                    )}
                </nav>
            </header>

            <section className="landing__hero">
                <p className="landing__eyebrow">Изучение языков · 2026</p>
                <h1 className="landing__title">Учите слова карточками.</h1>
                <p className="landing__lead">
                    Создавайте свои колоды, а сайт подскажет, какие слова пора повторить сегодня.
                    Всё работает в браузере, ничего устанавливать не нужно.
                </p>
                <div className="landing__cta">
                    <Link to="/signup" className="landing__btn landing__btn--large">Начать бесплатно</Link>
                </div>
            </section>

            {/* ... остальные блоки лендинга (Как это работает и т.д.) ... */}
        </div>
    );
}