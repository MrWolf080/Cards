import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import Header from '../components/Header.jsx';

export default function PopularDecks() {
    const [decks, setDecks] = useState(null);
    const [error, setError] = useState('');
    const [copyingId, setCopyingId] = useState(null);

    useEffect(() => {
        const controller = new AbortController();
        fetch('/api/v1/decks/popular', { credentials: 'include', signal: controller.signal })
            .then(response => {
                if (!response.ok) throw new Error('Не удалось загрузить колоды.');
                return response.json();
            })
            .then(setDecks)
            .catch(error => { if (!controller.signal.aborted) setError(error.message); });
        return () => controller.abort();
    }, []);

    const copyDeck = async deck => {
        setCopyingId(deck.id);
        setError('');
        try {
            const response = await fetch(`/api/v1/decks/${deck.id}/copy`, { method: 'POST', credentials: 'include' });
            if (!response.ok) throw new Error('Не удалось добавить колоду. Возможно, автор снял её с публикации.');
            const { id } = await response.json();
            setDecks(previous => previous.map(item => item.id === deck.id
                ? { ...item, copy_id: id, copies_count: item.copies_count + Number(response.status === 201) }
                : item).sort((a, b) => b.copies_count - a.copies_count || a.id - b.id));
        } catch (error) {
            setError(error.message);
        } finally {
            setCopyingId(null);
        }
    };

    return (
        <>
            <Header />
            <main className="page">
                <h1 className="page__title">Популярные колоды</h1>
                {error && <p role="alert">{error}</p>}
                {!decks && !error && <p>Загрузка…</p>}
                {decks?.length === 0 && <p>Пока никто не поделился колодой.</p>}
                {decks?.map(deck => (
                    <article className="deck-card" key={deck.id}>
                        <h2 className="deck-card__title"><Link to={`/decks/popular/${deck.id}`}>{deck.title}</Link></h2>
                        <div className="deck-card__footer">
                            <p>{deck.direction === 'ru_en' ? 'RU → EN' : 'EN → RU'} · Карточек: {deck.total_cards} · Добавлений: {deck.copies_count}</p>
                            <div className="deck-card__actions">
                            <Link className="btn btn--ghost" to={`/decks/popular/${deck.id}`}>Посмотреть слова</Link>
                            {deck.own || deck.copy_id
                                ? <Link className="btn btn--ghost" to={`/decks/${deck.copy_id ?? deck.id}`}>Открыть свою колоду</Link>
                                : <button className="btn" disabled={copyingId !== null} onClick={() => copyDeck(deck)}>Добавить к себе</button>}
                            </div>
                        </div>
                    </article>
                ))}
            </main>
        </>
    );
}
