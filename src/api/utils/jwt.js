import jwt from 'jsonwebtoken'

const secretHash = 'secretJwt'

export const sign = (payload, options) => {
    return jwt.sign(payload, secretHash, options)
}

export const verify = (token) => {
    return jwt.verify(token, secretHash, { complete: true, algorithms: ["HS256"] })
}