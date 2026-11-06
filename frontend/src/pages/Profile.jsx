import { useEffect, useState } from 'react';
import Header from '../components/Header.jsx';

export default function Profile() {
    const [profile, setProfile] = useState(null);
    const [errors, setErrors] = useState([]);
    const [saved, setSaved] = useState(false);
    const [saving, setSaving] = useState(false);

    useEffect(() => {
        fetch('/api/v1/profile', { credentials: 'include' })
            .then(async res => {
                if (!res.ok) throw new Error('Не удалось загрузить профиль. Обновите страницу.');
                setProfile(await res.json());
            })
            .catch(err => setErrors([err.message]));
    }, []);

    const change = (field, value) => {
        setProfile(previous => ({ ...previous, [field]: value }));
        setSaved(false);
        setErrors([]);
    };

    const save = async event => {
        event.preventDefault();
        setSaving(true);
        setSaved(false);
        setErrors([]);
        try {
            const res = await fetch('/api/v1/profile', {
                method: 'PATCH',
                credentials: 'include',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ profile: { daily_goal: profile.daily_goal, time_zone: profile.time_zone } })
            });
            const data = await res.json();
            if (!res.ok) {
                setErrors(data.errors || ['Не удалось сохранить настройки.']);
                return;
            }
            setProfile(data);
            setSaved(true);
        } catch {
            setErrors(['Не удалось сохранить настройки. Проверьте соединение и попробуйте снова.']);
        } finally {
            setSaving(false);
        }
    };

    return (
        <>
            <Header />
            <main className="page">
                <header className="page__header">
                    <h1 className="page__title">Профиль</h1>
                    <p className="page__subtitle">Настройте свой ритм обучения.</p>
                </header>
                {errors.length > 0 && <div role="alert">{errors.map(error => <p key={error}>{error}</p>)}</div>}
                {!profile ? <p>{errors.length ? 'Профиль недоступен.' : 'Загрузка...'}</p> : (
                    <form onSubmit={save} className="card profile-form">
                        <p className="page__subtitle">Аккаунт: {profile.email}</p>
                        <div className="auth__field">
                            <label className="auth__label" htmlFor="daily-goal">Дневная цель</label>
                            <input id="daily-goal" className="auth__input" type="number" min="1" max="1000" step="1" required
                                value={profile.daily_goal} onChange={event => change('daily_goal', event.target.value)}
                                aria-describedby="daily-goal-help" />
                            <p id="daily-goal-help" className="page__subtitle">От 1 до 1000 новых карточек в день. По умолчанию — 20. Карточка засчитывается при первом ответе, даже если вы её забыли. Повторения в цель не входят.</p>
                        </div>
                        <div className="auth__field">
                            <label className="auth__label" htmlFor="time-zone">Часовой пояс</label>
                            <select id="time-zone" className="auth__input" value={profile.time_zone}
                                onChange={event => change('time_zone', event.target.value)} aria-describedby="time-zone-help">
                                {profile.time_zones.map(zone => <option key={zone.value} value={zone.value}>{zone.label}</option>)}
                            </select>
                            <p id="time-zone-help" className="page__subtitle">Новый день начинается в полночь выбранного часового пояса. Он используется для дневной цели и дат повторения.</p>
                        </div>
                        <button className="btn" type="submit" disabled={saving}>{saving ? 'Сохранение...' : 'Сохранить настройки'}</button>
                        {saved && <p role="status">Настройки сохранены.</p>}
                    </form>
                )}
            </main>
        </>
    );
}
