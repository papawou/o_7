import { LobbyMember } from "./LobbyMember"
import { LobbyRequest } from "./LobbyRequest"

export const schema = `
interface LobbyUserInterface {
	id: ID!
	user: User!
	lobby: Lobby!
}

type LobbyUser implements LobbyUserInterface {
	id: ID!
	user: User!
	lobby: Lobby!

	status: LobbyBan|LobbyMember|LobbyRequest

	log_member:[LobbyMember]!
	log_requests: [LobbyRequest]!	
	log_bans: [LobbyBan]!
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

export class LobbyUserInterface {
	constructor(lobbyuser) {
		this._id_lobby = lobbyuser.id_lobby
		this._id_user = lobbyuser.id_user
	}

	static __typename = 'LobbyUserInterface'

	static encode(id_lobby, id_user) {
		return __typename + '_' + id_lobby + '-' + id_user
	}

	static decode(cid) {
		return cid.slice(LobbyUserInterface.__typename.length + 1).split('-')
	}

	static async gen(ctx, id_lobby, id_user) {
		let lobbyuser = await ctx.dl.lobbyuser.load(LobbyUserInterface.encode(id_lobby, id_user))
		return lobbyuser
	}

	static async load(ctx, cids) {
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
}

export class LobbyUser extends LobbyUserInterface {
	constructor(lobbyuser) {
		super(lobbyuser)
	}
	static __typename = "LobbyUser"

	static gen(ctx, id_lobby, id_user) {
		return new LobbyUser({ id_lobby: id_lobby, id_user: id_user })
	}
	async active_status(args, ctx) {
		let lobbyuser = await LobbyUserInterface.gen(ctx, this._id_lobby, this._id_user)
		return lobbyuser.fk_member !== null ? new LobbyMember(lobbyuser) :
			lobbyuser.status !== null ? new LobbyRequest(lobbyuser) :
				lobbyuser.ban_resolved_at !== null ? new LobbyBan(lobbyuser) : null
	}

	async log_requests(args, ctx) {
	}
	async log_bans(args, ctx) {
	}
}