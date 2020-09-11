import { Platform } from "./Platform"
import { Game } from "./Game"

export const schema = `
type GameCross {
	id: ID!
	
	game: Game!
  platforms: [Platform]!
}
`
export const resolvers = {
}

export class GameCross {
	constructor(gamecross) {
		this._id_cross = gamecross.id_cross
		this._id_game = gamecross.id_game

		this.id = GameCross.encode(this._id_game, this._id_cross)
	}
	static __typename = 'GameCross'

	//fields
	async game(args, ctx) {
		return await Game.gen(ctx, this._id_game)
	}
	async platforms(args, ctx) {
		let ids_platform = ctx.db.any("SELECT id_platform FROM game_platform WHERE id_game=$1 AND id_cross=$2", [this._id_game, this._id_cross])
		return await Promise.all(ids_platform.map(id_platform => Platform.gen(ctx, id_platform)))
	}

	//fetch
	static async gen(ctx, id_game, id_cross) {
		let gamecross = await ctx.dl.gamecross.load(GameCross.encode(id_game, id_cross))
		return gamecross ? new GameCross(gamecross) : null
	}
	/*
		//dataloader
		static async load(ctx, cids) {
			let cached_nodes = await ctx.redis.mget(cids)
			let pg_ids = { ids_game: [], ids_cross: [] }
	
			for (let i = 0; i < cached_nodes.length; i++) {
				if (cached_nodes[i] == null) {
					let unique_id = GameCross.decode(cid)
					pg_ids.ids_game.push(unique_id[0])
					pg_ids.ids_cross.push(unique_id[1])
				}
				else
					cached_nodes[i] = JSON.parse(cached_nodes[i])
			}
	
			if (pg_ids.length > 0) {
				let pg_nodes = await ctx.db.any(`
					SELECT row_to_json(games.*) as data
						FROM unnest(ARRAY[$1:csv]::integer[], ARRAY[$2:csv]::integer) WITH ORDINALITY key_id(id_game, id_cross)
						LEFT JOIN game_platform ON game_platform.id_game=key_id AND game_plaform
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
	*/
	//utils
	static encode(id_game, id_cross) {
		return GameCross.__typename + '_' + id_game + '-' + id_cross
	}

	static decode(cid) {
		return cid.slice(GameCross.__typename.length + 1).split('-')
	}
}