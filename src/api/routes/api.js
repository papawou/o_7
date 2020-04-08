import express from 'express'

import _user from './user/routes'

import api_search from './search'

const router = express.Router()

router.use('/user', _user)

router.use('/search', api_search)

router.use('*', (req, res) => {
	console.log('/api - ' + req.originalUrl)
	res.status(404).send()
})

export default router;