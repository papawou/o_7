import { redis } from './client'

export const mget = async (keys) => {
    return await redis.mget(keys)
}