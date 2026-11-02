import { useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';

export default function Login() {
    const [email, setEmail] = useState('');
    const [password, setPassword] = useState('');
    const [error, setError] = useState(null);
    const navigate = useNavigate();
    const { login } = useAuth();

    const handleSubmit = async (e) => {
        e.preventDefault();
        setError(null);

        try {
            const res = await fetch('/api/v1/session', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                credentials: 'include',
                body: JSON.stringify({ email_address: email, password })
            });

            const data = await res.json();

            if (res.ok) {
                login(data.user); // Обновляем контекст
                navigate('/'); // Редирект
            } else {
                setError(data.error || 'Ошибка входа');
            }
        } catch (err) {
            setError('Ошибка сети');
        }
    };

    return (
        <div className="auth">
            <div className="auth__card">
                <Link to="/" className="auth__back">← На главную</Link>
                <header className="auth__header">
                    <h1 className="auth__title">Вход</h1>
                    <p className="auth__subtitle">Введите email и пароль.</p>
                </header>

                {error && <div className="auth__alert">{error}</div>}

                <form onSubmit={handleSubmit} className="auth__form">
                    <div className="auth__field">
                        <label className="auth__label">Email</label>
                        <input
                            type="email"
                            className="auth__input"
                            value={email}
                            onChange={e => setEmail(e.target.value)}
                            required
                        />
                    </div>
                    <div className="auth__field">
                        <label className="auth__label">Пароль</label>
                        <input
                            type="password"
                            className="auth__input"
                            value={password}
                            onChange={e => setPassword(e.target.value)}
                            required
                        />
                    </div>
                    <button type="submit" className="auth__btn">Войти</button>
                </form>

                <footer className="auth__footer">
                    Нет аккаунта? <Link to="/signup" className="auth__link">Зарегистрироваться</Link>
                </footer>
            </div>
        </div>
    );
}