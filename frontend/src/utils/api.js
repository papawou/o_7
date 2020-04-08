export const afetch = async (url, data = {}) =>
	await fetch(`/api/${url}`,
		{
			method: 'POST',
			headers: {
				"Content-Type": "application/json"
			},
			body: JSON.stringify(data),
			credentials: 'same-origin'
		})
		.then(async response => {
			if (!response.ok)
				throw (await response.json())
			if (response.status == 204)
				return null
			return await response.json()
		})

export const authfetch = async (url, data = null) =>
	await fetch(`/api/${url}`,
		{
			method: 'POST',
			headers: {
				'Content-Type': "application/json"
			},
			credentials: 'same-origin',
			body: JSON.stringify(data)
		})
		.then(async response => {
			if (!response.ok)
				if (response.status == 401)
					throw (401)
				else if (response.status == 403)
					throw (403)
				else
					throw (await response.json())
			else if (response.status == 204)
				return null
			return await response.json()
		})

export const getfetch = async (url) => {
	let res = await fetch(url)
		.then(async response => {
			if (!response.ok)
				throw (response)
			return await response.json()
		})
	return res
}