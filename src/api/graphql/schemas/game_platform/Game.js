import { Platform } from "./Platform"
import { GameCross } from "./GameCross"

export const schema = `
type Game {
  id: ID!
  name: String!

  platforms: [Platform]!
  crosses: [GameCross]!
}

extend type Query {
  game(id: ID!): Game
}
`
export const resolvers = {
  Query: {
    game: async (obj, { id }, ctx, info) => {
      return await Game.gen(ctx, Game.decode(id))
    }
  }
}

export class Game {
  constructor(game) {
    this._id = game.id
    this.name = game.name

    this.id = Game.encode(this._id)
  }
  static __typename = 'Game'

  //fields
  async platforms(args, ctx) {
    let ids_platform = ctx.db.any("SELECT id_platform FROM game_platform WHERE id_game=$1", [this._id])
    return await Promise.all(ids_platform.map(id_platform => Platform.gen(ctx, id_platform)))
  }
  async crosses(args, ctx) {
    let ids_cross = ctx.db.any("SELECT DISTINCT id_cross FROM game_platform WHERE id_game=$1", [this._id])
    return await Promise.all(ids_cross.map(id_cross => GameCross.gen(ctx, this._id, id_cross)))
  }

  //fetch
  static async gen(ctx, id) {
    let game = await ctx.dl.game.load(Game.encode(id))
    return game ? new Game(game) : null
  }

  //dataloader
  static async load(ctx, cids) {
    let cached_nodes = await ctx.redis.mget(cids)
    let pg_ids = []

    for (let i = 0; i < cached_nodes.length; i++) {
      if (cached_nodes[i] == null)
        pg_ids.push(Game.decode(cids[i]))
      else
        cached_nodes[i] = JSON.parse(cached_nodes[i])
    }

    if (pg_ids.length > 0) {
      let pg_nodes = await ctx.db.any(`
        SELECT row_to_json(games.*) as data
          FROM unnest(ARRAY[$1:csv]::integer[]) WITH ORDINALITY key_id
          LEFT JOIN games ON games.id=key_id
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
  static encode(id_game) {
    return Game.__typename + '_' + id_game
  }

  static decode(cid) {
    return cid.slice(Game.__typename.length + 1)
  }
}