import Redis from 'ioredis'

//sudo service redis-server restart
export const redis = new Redis({
    port: 6379,
    host: '127.0.0.1'
})

export const test = async () => {
    try {
        await redis.ping()
    }
    catch (err) {
        throw('/!\\ REDIS FAILED')
    }
}