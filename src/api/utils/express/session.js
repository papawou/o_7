import Session from 'express-session'
import { redis } from '../../redis/client'

const _RedisStore = require('connect-redis')(Session)

export const RedisStore = new _RedisStore({ client: redis })

const cookieConfig = process.env.NODE_ENV === 'development' ? { httpOnly: false } : { httpOnly: true, sameSite: "strict", secure: true }

export const session = Session({
    store: RedisStore,
    secret: 'secretCookie',
    name: 'zobId',
    saveUninitialized: false,
    cookie: { httpOnly: false },
    resave: false
})