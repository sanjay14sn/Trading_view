const Redis = require('ioredis');
const config = require('../config');
const { logError } = require('./logger');

let redis;

const createMockRedis = () => {
    const store = new Map();
    const mock = {
        get: async (key) => store.get(key),
        set: async (key, val, ...args) => {
            // Parse variadic options: NX, EX <n>, PX <n>
            const upper = args.map(a => typeof a === 'string' ? a.toUpperCase() : a);
            const nxIndex = upper.indexOf('NX');
            const exIndex = upper.indexOf('EX');
            const pxIndex = upper.indexOf('PX');

            if (nxIndex !== -1 && store.has(key)) {
                return null; // NX: return null if key already exists
            }
            store.set(key, val);
            if (exIndex !== -1) {
                const ttl = upper[exIndex + 1];
                setTimeout(() => store.delete(key), ttl * 1000);
            } else if (pxIndex !== -1) {
                const ttl = upper[pxIndex + 1];
                setTimeout(() => store.delete(key), ttl);
            }
            return 'OK';
        },
        setnx: async (key, val) => {
            if (store.has(key)) return 0;
            store.set(key, val);
            return 1;
        },
        del: async (key) => store.delete(key),
        on: () => { },
        isMock: true,
        status: 'ready'
    };
    return mock;
};

const realRedis = new Redis(config.redis.url, {
    maxRetriesPerRequest: null,
    enableOfflineQueue: false,
    connectTimeout: 2000,
    retryStrategy: () => null
});

const mockRedis = createMockRedis();
let useMock = false;

realRedis.on('error', (err) => {
    if (!useMock) {
        console.warn('⚠️  Redis connection failed. Switching to internal mock.');
        useMock = true;
    }
});

// Proxy handler to switch between real and mock
redis = new Proxy(realRedis, {
    get: (target, prop) => {
        if (prop === 'isMock') return useMock;
        if (useMock && prop in mockRedis) return mockRedis[prop];
        return target[prop];
    }
});

module.exports = redis;
