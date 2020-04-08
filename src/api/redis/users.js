import { RedisStore } from './client'

export const getSDU = (zobId = null) => new Promise((resolve, reject) => {
    RedisStore.get(zobId, (error, sdu) => {
        if (error)
            reject(error)
        else if (sdu && sdu._id)
            resolve(sdu)
        else
            reject({ zob_err: "401", msg: "user not in a session" })
    })
})