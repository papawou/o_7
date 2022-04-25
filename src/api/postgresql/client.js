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

//const cmd_exec = require('util').promisify(require('child_process').exec);
const cmd_exec = require('child_process').execSync;

const connection = {
	host: cmd_exec("grep -m 1 nameserver /etc/resolv.conf | awk '{print $2}'").toString().replace("\n", ""),
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
	catch (err) {
		console.log(err);
		throw ("/!\\ POSTGRES FAILED")
	}
}

export default db