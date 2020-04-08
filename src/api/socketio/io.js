import * as _lobbys from './lobbys'
import _io from 'socket.io'
import * as _RedisStore from '../redis/users'


let io = _io()
export const start = async (server) => {
    try {
        io = _io(server, { cookie: false })
        init()
        exports.default = io
        await _lobbys.start()
        console.log('SOCKET.IO SUCCESS')
    }
    catch(err) {
        console.log(err)
        console.log('/!\\ SOCKET.IO FAILED')
    }
}

const init = () => {
    io.on('connection', (client) => {
        ///////////////////////////////
        getNspClients(io).then((clients) => {
            info(`/ +++ ${clients.length} +++ ${client.id} / ${client.handshake.zobId}`)
        })
        /// EVENTS
        client.on('disconnect', (reason) => {
            getNspClients(io).then((clients) => info(`/ --- ${clients.length} --- ${client.id} / ${client.handshake.zobId} - ${reason}`))
        })

        client.on('DEBUG', async (data) => {
            try {
                info(`DEBUG / - ${client.id}`)
                debug(io)
            }
            catch (e) {
                console.log(e)
            }
        })
    })
}

//UTILS
export const debug = async (nsp) => {
    let clients = await getNspClients(nsp)
    console.log(`- ${nsp.name ? nsp.name : 'io'} -`)
    console.log(clients)
    let rooms = await getNspRooms(nsp)
    rooms.forEach(room => {
        if (room) {
            console.log(`-- ROOM - ${room.roomname} --`)
            console.log(room.clients)
        }
    })
}
export const getNspClients = (nsp) => new Promise((resolve, reject) => {
    nsp.clients((error, clients) => {
        if (error)
            reject(error)
        resolve(clients)
    })
})
export const getNspRooms = async (nsp) => {
    let rooms = await Promise.all(Object.keys(nsp.name ? nsp.adapter.rooms : nsp.sockets.adapter.rooms).map(async roomname => {
        let room = null
        if (roomname[0] != '/')
            room = await new Promise((resolve, reject) => {
                nsp.in(roomname).clients((error, clients) => {
                    resolve(clients)
                })
            })
        return room ? { roomname: roomname, clients: room } : null
    }))

    return rooms
}

export const catchCustomError = (error, msg = null) => {
    console.log(error)
    return error.zob_err ? error : { zob_err: 'IO', mes: msg }
}

export const info = (string) => {
    console.log(`${string}`.bgYellow)
}