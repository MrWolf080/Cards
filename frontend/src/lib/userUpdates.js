import { createConsumer } from '@rails/actioncable';

export function connectUserUpdates(onEvent, onUnauthorized, consumerFactory = createConsumer) {
    const consumer = consumerFactory('/cable');
    const subscription = consumer.subscriptions.create('UserUpdatesChannel', {
        connected() { onEvent({ type: 'connection.restored' }); },
        received: onEvent,
        rejected() {
            consumer.disconnect();
            onUnauthorized();
        }
    });
    return () => {
        subscription.unsubscribe();
        consumer.disconnect();
    };
}
