export function mergeStudyQueue(previous, incoming, retained, existingIds, availableAnswers) {
    const key = item => item.id ?? item.card_id;
    const byId = new Map(incoming.map(item => [key(item), item]));
    const result = [];
    // Keep the current question and its option order stable while it remains valid.
    for (const item of previous) {
        if (byId.has(key(item))) {
            const optionsValid = !availableAnswers || !item.options || item.options.every(option => availableAnswers.includes(option));
            result.push(optionsValid ? item : byId.get(key(item)));
            byId.delete(key(item));
        }
    }
    result.push(...byId.values());
    if (retained && existingIds?.includes(key(retained))) {
        return [retained, ...result.filter(item => key(item) !== key(retained))];
    }
    return result;
}
