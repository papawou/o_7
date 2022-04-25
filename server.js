import express from 'express'
import path from 'path'
import { session } from './src/api/utils/express/session'
import api_routes from './src/api/routes/api'
import graphqlHTTP from './src/api/graphql/client'
import { express as voyagerMiddleware } from 'graphql-voyager/middleware'
import * as pgsql from './src/api/postgresql/client'
import * as socketio from './src/api/socketio/io'
import * as redis from './src/api/redis/client'


require("util").inspect.defaultOptions.colors = true
require('colors')

const app = express()
console.log(process.argv);
const environment = process.env.NODE_ENV
const staticPath = path.join(__dirname, '/frontend/public')
const port = 3000
const host = 'localhost'

app.use(session)
//express MIDDLEWARES
app.use(express.json())
app.use(express.urlencoded({ extended: true }))

//DEVELOPMENT
if (environment === 'development') {
	console.log('o==3 DEVELOPMENT STARTING... o==3')
}
else {
	console.log('!!! PRODUCTION STARTING... !!!')
}

//GraphQL
app.use('/voyager', voyagerMiddleware({ endpointUrl: '/graphql' }));
app.use('/graphql', graphqlHTTP)
//ROUTES
app.use(express.static(staticPath))
//
app.use('/api', api_routes)
app.use('*', (req, res) => {
	console.log('* CALLED - ' + req.originalUrl)
	res.sendFile(path.join(staticPath, 'index.html'))
})

const server = app.listen(port, host, async function () {
	try {
		await Promise.all([
			pgsql.test(),
			redis.test()
			//socketio.start(server)
		])
		console.log('--- server listening on ' + host + ':' + port + ' ---')

	}
	catch (err) {
		console.log(err)
		console.log('/!\\ SERVER FAILED')
		process.exit(1)
	}
})