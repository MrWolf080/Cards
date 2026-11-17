import { useEffect, useState } from 'react';
import { Link, useParams } from 'react-router-dom';
import Header from '../components/Header.jsx';

export default function DeckPreview() {
    const { id } = useParams();
    const [result, setResult] = useState(null);

    useEffect(() => {
        const controller = new AbortController();
        fetch(`/api/v1/decks/${id}/preview`, { credentials: 'include', signal: controller.signal })
            .then(response => {
                if (response.status === 404) throw new Error('Колода больше не доступна в каталоге.');
                if (!response.ok) throw new Error('Не удалось загрузить колоду.');
                return response.json();
            })
            .then(deck => setResult({ id, deck }))
            .catch(error => {
                if (!controller.signal.aborted) setResult({ id, error: error.message });
            });
        return () => controller.abort();
    }, [id]);

    const current = result?.id === id ? result : null;
    const deck = current?.deck;

    return (
        <>
            <Header />
            <main className="page">
                <Link to="/decks/popular" className="btn btn--ghost">К популярным колодам</Link>
                {!current && <p>Загрузка…</p>}
                {current?.error && <p role="alert">{current.error}</p>}
                {deck && (
                    <>
                        <h1 className="page__title">{deck.title}</h1>
                        <p className="page__subtitle">{deck.direction === 'ru_en' ? 'RU → EN' : 'EN → RU'} · Карточек: {deck.cards.length}</p>
                        {deck.cards.length === 0 ? <p>В этой колоде пока нет карточек.</p> : (
                            <div className="card">
                                <table className="table">
                                    <thead><tr><th>Слово</th><th>Перевод</th></tr></thead>
                                    <tbody>
                                        {deck.cards.map(card => (
                                            <tr key={card.id}>
                                                <td>{card.front}{card.example && <div className="page__subtitle">{card.example}</div>}</td>
                                                <td>{card.back}</td>
                                            </tr>
                                        ))}
                                    </tbody>
                                </table>
                            </div>
                        )}
                    </>
                )}
            </main>
        </>
    );
}
