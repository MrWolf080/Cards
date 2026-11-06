import { Link, useNavigate } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';

export default function Header() {
    const { user, logout } = useAuth();
    const navigate = useNavigate();

    const handleLogout = async () => {
        try {
            await fetch('/api/v1/session', {
                method: 'DELETE',
                credentials: 'include'
            });
            logout();
            navigate('/');
        } catch (error) {
            console.error('Ошибка при выходе', error);
        }
    };

    return (
        <header className="app-header">
            <div className="app-header__inner">
                <Link to="/" className="app-header__logo">К</Link>

                <nav className="app-header__nav">
                    <Link to="/dashboard">Панель</Link>
                    <Link to="/decks">Колоды</Link>
                    <Link to="/stats">Статистика</Link>
                </nav>

                <div className="app-header__right">
                    {user ? (
                        <>
                            <Link to="/profile" className="app-header__email" aria-label={`Профиль: ${user.email}`}>{user.email}</Link>
                            <button onClick={handleLogout} className="btn btn--ghost">Выйти</button>
                        </>
                    ) : (
                        <Link to="/login" className="btn">Войти</Link>
                    )}
                </div>
            </div>
        </header>
    );
}
