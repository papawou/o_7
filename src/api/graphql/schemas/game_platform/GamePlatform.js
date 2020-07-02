import { Platform } from "./Platform"
import { Game } from "./Game"
import { GameCross } from "./GameCross"

export const schema = `
type GamePlatform {
  id: ID!

	game: Game!
	platform: Platform!

	cross: GameCross
}
`
export const resolvers = {
}

export class GamePlatform {
	constructor(gameplatform) {
		this._id_game = gameplatform.id_game
		this._id_platform = gameplatform.id_platform
		this._id_cross = gameplatform.id_cross

		this.id = GamePlatform.encode(this._id_game, this._id_platform)
	}
	static __typename = 'GamePlatform'

	//fields
	async platform(args, ctx) {
		return await Platform.gen(ctx, this._id_platform)
	}
	async game(args, ctx) {
		return await Game.gen(ctx, this._id_game)
	}

	async cross(args, ctx) {
		if (this._id_cross !== null)
			return await GameCross.gen(ctx, this._id_game, this._id_cross)
		return null
	}

	//fetch
	static async gen(ctx, id_game, id_platform) {
		let gameplatform = await ctx.dl.gameplatform.load(GamePlatform.encode(id_game, id_platform))
		return gameplatform ? new GamePlatform(gameplatform) : null
	}

	//dataloader
	static async load(ctx, cids) {
		let cached_nodes = await ctx.redis.mget(cids)
		let pg_ids = { ids_game, ids_platform }

		for (let i = 0; i < cached_nodes.length; i++) {
			if (cached_nodes[i] == null) {
				let unique_id = GamePlatform.decode(cids[i])
				pg_ids.ids_game.push(unique_id[0])
				pg_ids.ids_game.push(unique_id[1])
			}
			else
				cached_nodes[i] = JSON.parse(cached_nodes[i])
		}

		if (pg_ids.length > 0) {
			let pg_nodes = await ctx.db.any(`
        SELECT row_to_json(game_platform.*) as data
          FROM unnest(ARRAY[$1:csv]::integer[], ARRAY[$2:csv]::integer[]) WITH ORDINALITY key_id(id_game, id_platform)
          LEFT JOIN game_plaform ON game_platform.id_game=key_id.id_game AND game_platform.id_platform=key_id.id_platform
          ORDER BY ordinality
        `, [pg_ids.ids_game, pg_ids.ids_platform])

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
	static encode(id_game, id_platform) {
		return GamePlatform.__typename + '_' + id_game + '-' + id_platform
	}

	static decode(cid) {
		return cid.slice(GamePlatform.__typename.length + 1).split('-')
	}
}