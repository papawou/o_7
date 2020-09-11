import initpgp from 'pg-promise'
import monitor from 'pg-monitor'

const initOptions = {/*
    connect(client, dc, useCount) {
        //console.log('POSTGRES_CONNECT: ' + useCount)
    },
    disconnect(client, dc) {
        //console.log('POSTGRES_DISCONNECT')
    },
    query(e) {
        console.log('POSTGRES_QUERY:\n' + e.query)
    },
    error(err, e) {
        console.log('POSTGRES_ERROR:\n' + err)
    }*/
}

monitor.attach(initOptions)

const pgp = initpgp(initOptions)

const connection = {
    host: 'localhost',
    port: 5432,
    database: 'zob',
    user: 'postgres',
    password: 'root'
}

const db = pgp(connection)

export const test = async () => {
    try {
        await db.one("SELECT 1")
    }
    catch {
        throw ("/!\\ POSTGRES FAILED")
    }
}

export default db