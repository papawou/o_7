import { signedCookie as _decodeCookie } from 'cookie-parser'
import { parse as _parseCookies } from 'cookie'

//import * as _lobby from '../controllers/lobby/lobby'
import io, * as _io from './io'
import * as _RedisStore from '../redis/users'

import test from 'socket.io'

const nsp_name = '/lobbys'
let nsp = test().of('/test')

export const start = async () => {
    nsp = io.of(nsp_name)
    nsp.use(nspAuth)
    init()
    exports.default = nsp
}

const init = () => {
    nsp.on('connection', (client) => {
        /*
        try {
            _RedisStore.getSDU(client.handshake.zobId)
                .then(async sdu => {
                    client.join(`user:${sdu._id}`)
                    let id_user = sdu._id
                    let id_lobby = await _lobby.checkUser(id_user)
                    let lobby = null
                    if (id_lobby) {
                        lobby = await _lobby.get(id_lobby)
                        client.join(`lobby:${id_lobby}`)
                    }
                    client.emit('init', lobby)
                })
                .catch(err => {
                    console.log(err)
                })
        }
        catch (e) {
            console.log(e)
        }

        _io.getNspClients(nsp).then((clients) => {
            _io.info(`${nsp.name} +++ ${clients.length} +++ ${client.id} / ${client.handshake.zobId}`)
        })

        //client middleware
        client.use((packet, next) => {
            _RedisStore.getSDU(client.handshake.zobId)
                .then(sdu => {
                    client.handshake.sdu = sdu
                    next()
                })
                .catch(err => {
                    console.log(err)
                    next(new Error('no session'))
                })
        })

        /// EVENTS
        client.on('lobby:join', async (id_lobby, ack) => {
            console.log('lobby:join')
            try {
                let id_user = client.handshake.sdu._id
                let curr_lobby = await _lobby.leave(id_user)
                if (curr_lobby) {
                    client.to(`lobby:${curr_lobby}`).emit('lobby:leave', { id_user: id_user })
                    client.leave(`lobby:${curr_lobby}`)
                }
                await _lobby.join(id_lobby, id_user)
                client.join(`lobby:${id_lobby}`)
                client.to(`lobby:${id_lobby}`).emit('lobby:join', { role: "default", _id: id_user, name: client.handshake.sdu.name })
                let lobby = await _lobby.get(id_lobby)
                ack(lobby)
            }
            catch (err) {
                ack(_io.catchCustomError(err, 'lobby:join'))
            }
        })
        client.on('lobby:leave', async () => {
            console.log('lobby:leave')
            try {
                let id_user = client.handshake.sdu._id
                let curr_lobby = await _lobby.leave(id_user)
                if (curr_lobby) {
                    client.to(`lobby:${curr_lobby}`).emit('lobby:leave', { id_user: id_user })
                    client.leave(`lobby:${curr_lobby}`)
                }
            }
            catch (err) {
                _io.catchCustomError(err, 'lobby:leave')
            }
        })

        client.on('lobby:create', async (data, ack) => {
            console.log('lobby:create')
            try {
                let id_user = client.handshake.sdu._id
                let id_lobby = await _lobby.create(id_user, data)
                client.join(`lobby:${id_lobby}`)
                let lobby = await _lobby.get(id_lobby)
                ack(lobby)
            }
            catch (err) {
                ack(_io.catchCustomError(err, 'lobby:create'))
            }
        })

        //TODO security issues data.id_lobby
        //how to handle ack and emit('cv:join') for free user_prevcv
        client.on('cv:join', async (data, ack) => {
            _io.info(`cv:join: ${data.id_cv}`)
            try {
                let id_user = client.handshake.sdu._id
                if (!id_user)
                    throw ('not logged')
                let res = await _lobby.joinCv(data.id_cv, id_user)
                client.to(`lobby:${data.id_lobby}`).emit('cv:join', { id_newcv: res.id_newcv, id_prevcv: res.id_prevcv, id_owner: id_user })
                ack({ id_newcv: res.id_newcv, id_prevcv: res.id_prevcv })
            }
            catch (err) {
                ack(_io.catchCustomError(err, 'cv:join'))
            }
        })

        client.on('cv:leave', async (data, ack) => {
            _io.info(`cv:leave: ${data.id_cv}`)
            try {
                let id_user = client.handshake.sdu._id
                if (!id_user)
                    throw ('not logged')
                await _lobby.leaveCv(id_user)
                //TODO change data.id_lobby and data.id_cv with values from User.cv
                client.to(`lobby:${data.id_lobby}`).emit('cv:leave', { id_cv: data.id_cv })
                ack({ id_cv: data.id_cv })
            } catch (err) {
                ack(_io.catchCustomError(err, 'cv:leave'))
            }
        })


        client.on('disconnect', async (reason) => {
            _io.getNspClients(nsp).then((clients) => _io.info(`${nsp.name} --- ${clients.length} --- ${client.id} / ${client.handshake.zobId} - ${reason}`))
        })
        client.on('disconnecting', (reason) => {
            try {
                if (!client.handshake.zobId)
                    throw ('ON DISCONNECTING - NO ACCOUNT ATTACHED TO CLIENT')
                let user_room = Object.keys(client.rooms).find(room_name => /^user:/.test(room_name))
                if (client.adapter.rooms[user_room].length <= 1)
                    _RedisStore.getSDU(client.handshake.zobId)
                        .then(async sdu => {
                            let id_lobby = await _lobby.leave(sdu._id)
                            if (id_lobby)
                                nsp.to(`lobby:${id_lobby}`).emit('lobby:leave', { id_user: sdu._id })
                        })
                        .catch(err => console.log(err))
            }
            catch (e) {
                console.log(e)
            }
        })

        client.on('DEBUG', async (data) => {
            try {
                _io.info(`DEBUG /lobbys - ${client.id}`)
                _io.debug(nsp)
            }
            catch (e) {
                console.log(e)
            }
        })
    */
    })
}

const nspAuth = function (socket, next) {
    try {
        if (socket.handshake.headers.cookie) {
            let cookie = _parseCookies(socket.handshake.headers.cookie)['zobId']
            let zobId = _decodeCookie(cookie, 'secretCookie')
            if (zobId)
                socket.handshake.zobId = zobId
            else
                throw ('no zobId')
        }
        else {
            throw ('no headers.cookie')
        }
        next()
    }
    catch (e) {
        console.log('ZOBAUTH_ERROR: ' + e)
        next(new Error({ zob_err: 401, msg: "user not logged" }))
    }
}