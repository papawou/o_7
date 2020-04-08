import express from 'express'
import db from '../../postgresql/client'

const router = express.Router()

//logUser
router.post('/log', async (req, res) => {
    try {
        console.log(`user/log - ${req.session.name} / ${req.sessionID}`)
        if (!req.session._id)
            throw ("unlogged")
        let user = await db.one('SELECT id, name FROM users WHERE id=$1', req.session._id)
        res.send(user)
    }
    catch (err) {
        console.log(err)
        clearSession(req, res)
        res.status(401).send()
    }
})

//login
router.post('/login', async (req, res) => {
    try {
        console.log(`login - ${req.body.name} / ${req.sessionID}`)
        if (req.session._id)
            throw ('already logged')
        if (!(req.body.name && req.body.password))
            throw ('params missing')

        let user = await db.one('SELECT id, name FROM users WHERE name=$1 AND password=$2', [req.body.name, req.body.password])

        req.session._id = user.id
        req.session.name = user.name
        res.send(user)
    }
    catch (err) {
        console.log(err)
        clearSession(req, res)
        res.status(400).send()
    }
})

//logout
router.post('/logout', (req, res) => {
    console.log('logout - ' + req.sessionID)
    clearSession(req, res)
    res.status(204).send()
})

const clearSession = (req, res) => {
    req.session.destroy()
    res.clearCookie('zobId', { path: '/', httpOnly: 'false' })
}

export default router