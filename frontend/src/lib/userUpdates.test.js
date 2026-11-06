import { test } from 'node:test';
import assert from 'node:assert/strict';
import { connectUserUpdates } from './userUpdates.js';

function fakeConsumer() {
    const state = { disconnects: 0, unsubscribes: 0 };
    state.consumer = {
        disconnect() { state.disconnects++; },
        subscriptions: {
            create(channel, callbacks) {
                assert.equal(channel, 'UserUpdatesChannel');
                state.callbacks = callbacks;
                return { unsubscribe() { state.unsubscribes++; } };
            }
        }
    };
    state.factory = url => { assert.equal(url, '/cable'); return state.consumer; };
    return state;
}

test('initial connection and each reconnection request a single refresh', () => {
    const state = fakeConsumer();
    const events = [];
    const close = connectUserUpdates(event => events.push(event), () => {}, state.factory);
    state.callbacks.connected();
    state.callbacks.connected();
    state.callbacks.received({ type: 'card.reviewed', data: { deck_id: 1 } });
    assert.deepEqual(events.map(event => event.type), ['connection.restored', 'connection.restored', 'card.reviewed']);
    close();
    assert.equal(state.disconnects, 1);
    assert.equal(state.unsubscribes, 1);
});

test('rejected subscription closes the socket and invalidates authentication', () => {
    const state = fakeConsumer();
    let unauthorized = false;
    connectUserUpdates(() => {}, () => { unauthorized = true; }, state.factory);
    state.callbacks.rejected();
    assert.equal(state.disconnects, 1);
    assert.equal(unauthorized, true);
});
