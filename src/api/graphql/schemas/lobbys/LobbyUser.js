export const schema = `
interface LobbyUserInterface {
	id: ID!
	user: User!
	lobby: Lobby!
}

type LobbyBan implements LobbyUserInterface {
	id: ID!
	user: User!
	lobby: Lobby!

	ban_resolved_at: String!
	created_at: User!
	created_by: User!
}

type LobbyMember implements LobbyUserInterface {
	id: ID!
	user: User!
	lobby: Lobby!

	joined_at: String!
}

type LobbyRequest implements LobbyUserInterface {
	id: ID!
	user: User!
	lobby: Lobby!

	created_at: String
	status: LobbyRequestStatus
}
`
export const resolvers = {
	LobbyUserInterface: {
		__resolveType: (obj, args, ctx, info) => obj ? obj.__typename : null
	}
}

const __typename = 'LobbyUserInterface'

const encode = (id_lobby, id_user) => {
	return __typename + '_' + id_lobby + '-' + id_user
}

const decode = (cid) => {
	return cid.slice(LobbyUserInterface.__typename.length + 1).split('-')
}

export const gen = async (ctx, id_lobby, id_user) => {
	let lobbyuser = await ctx.dl.lobbyuser.load(encode(id_lobby, id_user))
	return lobbyuser
}

export const load = async (ctx, cids) => {
	let cached_nodes = await ctx.redis.mget(cids)
	let pg_ids = { ids_lobby: [], ids_user: [] }

	for (let i = 0; i < cached_nodes.length; i++) {
		if (cached_nodes[i] == null) {
			let unique_id = decode(cids[i])
			pg_ids.ids_lobby.push(unique_id[0])
			pg_ids.ids_user.push(unique_id[1])
		}
		else
			cached_nodes[i] = JSON.parse(cached_nodes[i])
	}

	if (pg_ids.ids_lobby.length > 0) {
		let pg_nodes = await ctx.db.any(`
        SELECT row_to_json(lobby_users.*) as data
          FROM unnest(ARRAY[$1:csv]::integer[], ARRAY[$1:csv]::integer[]) WITH ORDINALITY key_id(id_lobby, id_user)
          LEFT JOIN lobbys ON lobby_users.id_lobby=key_id.id_lobby AND lobby_users.id_user=key_id.id_user
          ORDER BY ordinality
        `, [pg_ids.ids_lobby, pg_ids.ids_user])

		let pg_map = new Map()
		for (let i = 0; i < cached_nodes.length; i++) {
			if (cached_nodes[i] == null) {
				if (pg_nodes[0].data !== null) {
					pg_map.set(cids[i], JSON.stringify(pg_nodes[0].data))
					cached_nodes[i] = pg_nodes.shift().data
				}
				else
					pg_nodes.shift()
			}
		}
		if (pg_map.size > 0)
			await ctx.redis.mset(pg_map)
	}

	return cached_nodes
}