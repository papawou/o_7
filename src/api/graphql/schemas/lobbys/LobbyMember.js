import { User } from "../users/User"
import { Lobby } from "./Lobby"
import * as LobbyUserInterface from './LobbyUser'

export const schema = `
interface LobbyMemberInterface {
  id: ID!
	user: User!
  lobby: Lobby!
}

type LobbyMember implements LobbyMemberInterface {
	id: ID!
	user: User!
	lobby: Lobby!
}

type LobbyMemberEdge implements LobbyMemberInterface {
	id: ID!
	user: User!
	lobby: Lobby!

	node: User!
}

extend type Query {
	lobbymember(id: ID!): LobbyMember
}
`
export const resolvers = {
	Query: {
		lobbymember: async (obj, { id }, ctx, info) => {
			return await LobbyMember.gen(ctx, LobbyMember.decode(id))
		}
	}
}

export class LobbyMember {
	constructor(lobbymember) {
		this._id_lobby = lobbymember.id_lobby
		this._id_user = lobbymember.fk_member

		this.id = LobbyMember.encode(lobbymember.id_lobby, lobbymember.id_user)
	}
	static __typename = 'LobbyMember'

	//field
	async user(args, ctx) {
		return await User.gen(ctx, this._id_user)
	}
	async lobby(args, ctx) {
		return await Lobby.gen(ctx, this._id_lobby)
	}

	//fetch
	static async gen(ctx, id_lobby, id_user) {
		let lobbymember = LobbyUserInterface.gen(ctx, id_lobby, id_user)
		return lobbymember.fk_member ? new LobbyMember(lobbymember) : null
	}

	//dataloader
	static async load(ctx, ids) {
		let cached_nodes = await ctx.redis.mget(ids)
		let pg_ids = { ids_lobby: [], ids_user: [] }

		for (let i = 0; i < cached_nodes.length; i++) {
			if (cached_nodes[i] == null) {
				let unique_id = LobbyMember.decode(ids[i])
				pg_ids.ids_lobby.push(unique_id[0])
				pg_ids.ids_user.push(unique_id[1])
			}
			else
				cached_nodes[i] = JSON.parse(cached_nodes[i])
		}

		if (pg_ids.ids_lobby.length > 0) {
			let pg_nodes = await ctx.db.any(`
        SELECT row_to_json(lobby_users.*) as data
          FROM unnest(ARRAY[$1:csv]::integer[], ARRAY[$2:csv]::integer[]) WITH ORDINALITY key_id(id_lobby, id_user)
          LEFT JOIN lobby_users ON lobby_users.id_lobby=key_id.id_lobby AND lobby_users.fk_member=key_id.id_user
          ORDER BY ordinality
        `, [pg_ids.ids_lobby, pg_ids.ids_user])

			let pg_map = new Map()
			for (let i = 0; i < cached_nodes.length; i++) {
				if (cached_nodes[i] == null) {
					if (pg_nodes[0].data !== null) {
						pg_map.set(ids[i], JSON.stringify(pg_nodes[0].data))
					}
					cached_nodes[i] = pg_nodes.shift().data
				}
			}
			if (pg_map.size > 0)
				await ctx.redis.mset(pg_map)
		}
		return cached_nodes
	}

	//utils
	static encode(id_lobby, id_user) {
		return LobbyMember.__typename + '_' + id_lobby + '-' + id_user
	}

	static decode(cid_lobby) {
		return cid_lobby.slice(LobbyMember.__typename.length + 1).split('-')
	}
}

class LobbyMemberEdge extends LobbyMember {
	static __typename = 'LobbyMemberEdge'

	//fields
	async node(args, ctx) {
		return User.gen(ctx, this._id_user)
	}
}

export class LobbyMemberConnection {
	constructor(id_lobby, ids_member) {
		this._id_lobby = id_lobby
		this.ids_member = ids_member
		this.count = ids_member.length
	}
	static __typename = 'LobbyMemberConnection'

	//fields
	async edges(args, ctx) {
		return await Promise.all(this._ids_member.map(async id_user => await LobbyMemberEdge.gen(ctx, LobbyMember.encode(this._id_lobby, id_user))))
	}

	//fetch
	static async gen(ctx, id_lobby) {
		let ids_member = await ctx.dl.lobbymembers.load('' + id_lobby)
		return new FriendshipConnection(id_lobby, ids_member)
	}

	//dataloader
	static async load(ctx, ids) {
		let cids = ids.map(id => LobbyMemberConnection.encode(id))
		let cached_nodes = await ctx.redis.mget(cids)
		let pg_ids = []

		for (let i = 0; i < cached_nodes.length; i++) {
			if (cached_nodes[i] == null)
				pg_ids.push(ids[i])
			else
				cached_nodes[i] = JSON.parse(cached_nodes[i])
		}
		if (pg_ids.length > 0) {
			let pg_nodes = await ctx.db.any(`
        SELECT array_remove(array_agg(lobby_users.fk_member), null) as data
          FROM unnest(ARRAY[$1:csv]::integer[]) WITH ORDINALITY key_id
          LEFT JOIN lobby_users ON lobby_users.id_lobby=key_id AND lobby_users.fk_member IS NOT NULL
          GROUP BY ordinality ORDER BY ordinality;
        `, [pg_ids])

			let pg_map = new Map()
			for (let i = 0; i < cached_nodes.length; i++) {
				if (cached_nodes[i] == null) {
					if (pg_nodes[0].data.length > 0) {
						pg_map.set(cids[i], JSON.stringify(pg_nodes[0].data))
					}
					cached_nodes[i] = pg_nodes.shift().data
				}
			}
			if (pg_map.size > 0)
				await ctx.redis.mset(pg_map)
		}
		return cached_nodes
	}

	//utils
	static encode(id_lobby) {
		return LobbyMemberConnection.__typename + '_' + id_lobby
	}

	static decode(cid) {
		return cid.slice(LobbyMemberConnection.__typename.length + 1)
	}
}