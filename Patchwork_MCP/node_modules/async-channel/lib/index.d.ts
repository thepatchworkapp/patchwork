/**
 * Error used to signal that a channel has been closed.
 * This can be detected for graceful handling.
 */
export declare class ChannelClosedError extends Error {
}
/**
 * Error used to signal that a channel has been cleared.
 * This may be thrown to senders who are waiting on the channel.
 */
export declare class ChannelClearedError extends Error {
}
/**
 * Error used to indicate that an operation is not supported.
 * This is currently used to disallow some operations in iterator-based Channels.
 */
export declare class UnsupportedOperationError extends Error {
}
declare type MaybePromise<T> = T | PromiseLike<T>;
/**
 * A BaseChannel serves as a way to send asynchronous values across concurrent lines of execution.
 */
export declare class BaseChannel<T> {
    readonly bufferCapacity: number;
    /** List of senders waiting for a receiver / buffer space */
    protected _senders: {
        item: Promise<T>;
        resolve: () => unknown;
        reject: (err: any) => unknown;
    }[];
    /** A list of receivers waiting for an item to be sent */
    protected _receivers: {
        resolve: (value: MaybePromise<T>) => unknown;
        reject: (err: any) => unknown;
    }[];
    private _onClose;
    private _onClosePromise;
    /** A list of buffered items in the channel */
    protected _buffer: Array<Promise<T>>;
    /** true if the channel is closed and should no longer accept new items. */
    private _closed;
    /**
     * Create a new Channel.
     * @param bufferCapacity The maximum number of items to buffer.
     *   Defaults to 0; i.e. all push()/throw() calls will wait for a matching then() call.
     */
    constructor(bufferCapacity?: number);
    /**
     * Send a new value over the channel.
     * @param value The value to send, or a Promise resolving to a value.
     * @returns A Promise that resolves when the value has been successfully pushed.
     */
    push(value: T | PromiseLike<T>): Promise<void>;
    /**
     * Throw a new error in the channel. Note that errors are also buffered and subject to buffer capacity.
     * @param value The error to throw.
     * @returns A Promise that resolves when the error has been successfully thrown.
     */
    throw(error: unknown): Promise<void>;
    /**
     * Close this channel.
     * @param clear Pass true to clear all buffered items / senders when closing the Channel. Defaults to false.
     */
    close(clear?: boolean): void;
    /**
     * Clear the channel of all buffered items.
     * Also throws a `ChannelClearedError` to awaiting senders.
     * Does not close the Channel.
     */
    clear(): Promise<T>[];
    /**
     * Wait for the next value (or error) on this channel.
     * @returns A Promise that resolves/rejects when the next value (or error) on this channel is emitted.
     */
    get(): Promise<T>;
    /**
     * Wait for the next value (or error) on this channel and process it.
     * Shorthand for `chan.get().then(...)`.
     */
    then<U = T, V = never>(onvalue?: ((value: T) => MaybePromise<U>) | undefined | null, onerror?: ((error: any) => MaybePromise<V>) | undefined | null): Promise<U | V>;
    /**
     * The number of items currently buffered.
     */
    get bufferSize(): number;
    /**
     * True if this channel is closed and no longer accepts new values.
     */
    get closed(): boolean;
    /**
     * A Promise that will resolve when this Channel is closed.
     */
    get onClose(): Promise<void>;
    /**
     * Returns true if this channel is closed and contains no buffered items or waiting senders.
     */
    get done(): boolean;
    /**
     * Enables async iteration over the channel.
     * The iterator will stop and throw on the first error encountered.
     */
    [Symbol.asyncIterator](): AsyncGenerator<T>;
    /**
     * Throws the given error to all waiting receivers.
     * Useful if you want to interrupt all waiting routines immediately.
     */
    interrupt(error: unknown): void;
    /**
     * Send the given Item. Returns a Promise that resolves when sent.
     */
    protected _send(item: Promise<T>): Promise<void>;
}
/**
 * A Channel extends BaseChannel and provides additional functionality.
 * This includes performing concurrent processing, serving iterators, limiting, etc.
 */
export declare class Channel<T> extends BaseChannel<T> {
    /**
     * Creates a new Channel from a given source.
     * @param values An Array-like or iterable object containing values to be processed.
     */
    static from<T>(source: ArrayLike<MaybePromise<T>> | Iterable<MaybePromise<T>> | AsyncIterable<T>): Channel<T>;
    /**
     * Creates a new Channel for the given values.
     * A new Channel will be created with these values.
     * @param values A list of values to be processed. These may be Promises, in which case they will be flattened.
     */
    static of<T>(...values: MaybePromise<T>[]): Channel<T>;
    /**
     * Returns a new Channel that reads up to `n` items from this Channel
     * @param n The number of items to read from this Channel
     */
    take(n: number): Channel<T>;
    /**
     * Applies a transformation function, applying the transformation to this Channel until it is empty and
     * @param func The transformation function.
     *   This function may read from the given input channel and write to the given output channel as desired.
     *   Because this function should at minimum read from the input channel, and possibly write to the output channel, it should return a Promise in order for concurrency limits to be obeyed.
     * @param concurrency The number of "coroutines" to spawn to perform this operation. Must be positive and finite. Defaults to 1.
     * @param bufferCapacity The buffer size of the output channel. Defaults to 0.
     */
    transform<U>(func: (input: Channel<T>, output: Channel<U>) => Promise<void>, concurrency?: number, bufferCapacity?: number): Channel<U>;
    /**
     * Applies the given 1-to-1 mapping function to this Channel and returns a new Channel with the mapped values.
     * @param onvalue A function that maps values from this Channel.
     *   To map to an error, either throw or return a rejecting Promise.
     *   May return a Promise or a plain value. If omitted, values will be propagated as-is.
     * @param onerror A function that maps errors from this Channel to *values*.
     *   To map to an error, either throw or return a rejecting Promise.
     *   May return a Promise or a plain value. If omitted, errors will be propagated as-is.
     * @param concurrency The number of "coroutines" to spawn to perform this operation. Must be positive and finite. Defaults to 1.
     * @param bufferCapacity The buffer size of the output channel. Defaults to 0.
     */
    map<U = T, V = never>(onvalue?: ((value: T) => MaybePromise<U>) | undefined | null, onerror?: ((error: any) => MaybePromise<V>) | undefined | null, concurrency?: number, bufferCapacity?: number): Channel<U | V>;
    /**
     * Applies the given filter function to the values from this Channel and returns a new Channel with only the filtered values.
     * @param onvalue A function that takes a value from this Channel and returns a boolean of whether to include the value in the resulting Channel.
     *   May return a Promise or a plain value. Defaults to passing all values.
     * @param onerror A function that takes an error from this Channel and returns a boolean of whether to include the error in the resulting Channel.
     *   May return a Promise or a plain value. Defaults to passing all values.
     * @param concurrency The number of "coroutines" to spawn to perform this operation. Must be positive and finite. Defaults to 1.
     * @param bufferCapacity The buffer size of the output channel. Defaults to 0.
     */
    filter(onvalue?: ((value: T) => MaybePromise<boolean>) | undefined | null, onerror?: ((error: any) => MaybePromise<boolean>) | undefined | null, concurrency?: number, bufferCapacity?: number): Channel<T>;
    /**
     * Consumes each value from this Channel, applying the given function on each. Errors on the Channel or in the function will cause the returned Promise to reject.
     * @param onvalue A function to invoke with each value from this Channel.
     * @param onerror A function to invoke with each error from this Channel.
     * @param concurrency The number of "coroutines" to spawn to perform this operation. Must be positive and finite. Defaults to 1.
     * @returns A Promise that resolves when all values have been consumed, or rejects when an error is received from the Channel.
     */
    forEach(onvalue?: ((value: T) => unknown) | undefined | null, onerror?: ((error: any) => unknown) | undefined | null, concurrency?: number): Promise<void>;
    /**
     * Consumes the values in this Channel and inserts them into an Array.
     * Returns a Promise that resolves to that Array if no errors were emitted.
     */
    toArray(): Promise<T[]>;
    /**
     * General function for applying a consumer function with multiple "coroutines" until the Channel is done.
     * Also handles errors by stopping all routines.
     */
    private _consume;
}
/**
 * An IteratorChannel automatically emits values from an (async-)iterable source.
 * It uses a pull-based mechanism for fetching the values -- i.e. iteration is not started until the first get() call is made.
 */
export declare class IteratorChannel<T> extends Channel<T> {
    private limit;
    private readonly _iterator;
    /**
     * Create a new IteratorChannel.
     * @param source the iterable source to take elements from.
     * @param limit An optional maximum number of items to take from the source before closing this Channel.
     */
    constructor(source: Iterable<MaybePromise<T>> | AsyncIterable<T>, limit?: number);
    push(value: T | PromiseLike<T>): Promise<void>;
    throw(error: unknown): Promise<void>;
    clear(): Promise<T>[];
    get(): Promise<T>;
    private _iterating;
    private _iterate;
}
export {};
