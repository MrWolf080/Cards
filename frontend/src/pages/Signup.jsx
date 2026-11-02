import { useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';

export default function Signup() {
    const [email, setEmail] = useState('');
    const [password, setPassword] = useState('');
    const [passwordConfirmation, setPasswordConfirmation] = useState('');
    const [errors, setErrors] = useState([]);
    const navigate = useNavigate();
    const { login } = useAuth();

    const handleSubmit = async (e) => {
        e.preventDefault();
        setErrors([]);

        const res = await fetch('/api/v1/registration', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                user: {
                    email_address: email,
                    password,
                    password_confirmation: passwordConfirmation
                }
            })
        });

        const data = await res.json();

        if (res.ok) {
            login(data.user);
            navigate('/dashboard');
        } else {
            setErrors(data.errors || ['Ошибка регистрации']);
        }
    };

    return (
        <div className="auth">
            <div className="auth__card">
                <Link to="/" className="auth__back">← На главную</Link>
                <header className="auth__header">
                    <h1 className="auth__title">Регистрация</h1>
                </header>

                {errors.length > 0 && (
                    <div className="auth__errors">
                        <ul>
                            {errors.map((err, i) => <li key={i}>{err}</li>)}
                        </ul>
                    </div>
                )}

                <form onSubmit={handleSubmit} className="auth__form">
                    <div className="auth__field">
                        <label className="auth__label">Email</label>
                        <input type="email" className="auth__input" value={email} onChange={e => setEmail(e.target.value)} required />
                    </div>
                    <div className="auth__field">
                        <label className="auth__label">Пароль</label>
                        <input type="password" className="auth__input" value={password} onChange={e => setPassword(e.target.value)} required minLength="8" />
                    </div>
                    <div className="auth__field">
                        <label className="auth__label">Подтверждение пароля</label>
                        <input type="password" className="auth__input" value={passwordConfirmation} onChange={e => setPasswordConfirmation(e.target.value)} required minLength="8" />
                    </div>
                    <button type="submit" className="auth__btn">Создать аккаунт</button>
                </form>

                <footer className="auth__footer">
                    Уже есть аккаунт? <Link to="/login" className="auth__link">Войти</Link>
                </footer>
            </div>
        </div>
    );
}