import express from 'express'

const router = express.Router()

//textSearch
router.post('/game', (req, res) => {
	console.log('search/game')
})

const catchCustomError = (error, api_code = null) => error.api_code ? error : { api_code: `SEARCH - ${api_code}`, msg: 'SEARCH error' }

export default router