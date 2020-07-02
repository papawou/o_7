import { Game } from "./Game"

export const schema = `
type Platform {
  id: ID!
  name: String!

	games: [Game]!
}

extend type Query {
  platform(id: ID!): Platform
}
`
export const resolvers = {
	Query: {
		platform: async (obj, { id }, ctx, info) => {
			return await Platform.gen(ctx, Platform.decode(id))
		}
	}
}

export class Platform {
	constructor(platform) {
		this._id = platform.id
		this.name = platform.name

		this.id = Platform.encode(platform.id)
	}
	static __typename = 'Platform'

	//fields
	async games(args, ctx) {
		let ids_game = ctx.db.any("SELECT id_game FROM game_platform WHERE id_platform=$1", [this._id])
		return await Promise.all(ids_game.map(id_game => Game.gen(ctx, id_game)))
	}

	//fetch
	static async gen(ctx, id) {
		let platform = await ctx.dl.platform.load(Platform.encode(id))
		return platform ? new Platform(platform) : null
	}

	//dataloader
	static async load(ctx, cids) {
		let cached_nodes = await ctx.redis.mget(cids)
		let pg_ids = []

		for (let i = 0; i < cached_nodes.length; i++) {
			if (cached_nodes[i] == null)
				pg_ids.push(Platform.decode(cids[i]))
			else
				cached_nodes[i] = JSON.parse(cached_nodes[i])
		}

		if (pg_ids.length > 0) {
			let pg_nodes = await ctx.db.any(`
        SELECT row_to_json(platforms.*) as data
          FROM unnest(ARRAY[$1:csv]::integer[]) WITH ORDINALITY key_id
          LEFT JOIN platforms ON platforms.id=key_id
          ORDER BY ordinality
        `, [pg_ids])

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

	//utils
	static encode(id_platform) {
		return Platform.__typename + '_' + id_platform
	}

	static decode(cid) {
		return cid.slice(Platform.__typename.length + 1)
	}
}