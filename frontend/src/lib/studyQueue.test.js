import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mergeStudyQueue } from './studyQueue.js';

test('remote reviews and deletes remove cards while new cards join the queue', () => {
    const previous = [{ id: 1 }, { id: 2 }, { id: 3 }];
    assert.deepEqual(mergeStudyQueue(previous, [{ id: 3 }, { id: 4 }]), [{ id: 3 }, { id: 4 }]);
});

test('current question keeps its option order across refreshes', () => {
    const current = { card_id: 1, options: ['a', 'b', 'c', 'd'] };
    assert.deepEqual(mergeStudyQueue([current], [{ card_id: 1, options: ['d', 'c', 'b', 'a'] }]), [current]);
});

test('answered question is retained until next, even though it is no longer due', () => {
    const answered = { card_id: 1 };
    const remaining = { card_id: 2 };
    assert.deepEqual(mergeStudyQueue([answered, remaining], [remaining], answered, [1, 2]), [answered, remaining]);
    assert.deepEqual(mergeStudyQueue([remaining], [remaining], null, [1, 2]), [remaining]);
});

test('deleted answered question cannot be retained', () => {
    assert.deepEqual(mergeStudyQueue([{ card_id: 1 }], [], { card_id: 1 }, []), []);
});

test('deleted distractors are replaced in unanswered questions', () => {
    const oldQuestion = { card_id: 1, options: ['a', 'removed'] };
    const newQuestion = { card_id: 1, options: ['a', 'new'] };
    assert.deepEqual(mergeStudyQueue([oldQuestion], [newQuestion], null, [1], ['a', 'new']), [newQuestion]);
});
