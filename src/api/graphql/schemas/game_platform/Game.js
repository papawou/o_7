import { GamePlatformEdge, GamePlatform, GameCross } from "./GamePlatform"

export const schema = `
type Game {
  id: ID!
  name: String!

  gamecross(id: ID!): GameCross

  platform(id: ID!): GamePlatform
  platforms: GamePlatformsConnection
}

type GamePlatformsConnection {
  edges: [GamePlatformEdge]!
}

extend type Query {
  game(id: ID!): Game
}`
export const resolvers = {
  Query: {
    game: (obj, { id }, ctx, info) => Game.gen(id, ctx)
  }
}

export class Game {
  constructor(game) {
    this.id = game.id
    this.name = game.name
  }
  static __typename = 'Game'

  async platforms(args, ctx) {
    return GamePlatformsConnection.gen(this.id, ctx)
  }
  async platform({ id }, ctx) {
    return GamePlatform.gen(this.id, id, ctx)
  }
  async gamecross({ id }, ctx) {
    return GameCross.gen(this.id, id, ctx)
  }

  static async gen(id, ctx) {
    let game = await ctx.dl.game.load(parseInt(id))
    return game ? new Game(game) : null
  }
  static async load(ids, ctx) {
    let games = await ctx.db.any(`
    SELECT row_to_json(games.*) as data
    FROM unnest(ARRAY[$1:csv]::integer[]) WITH ORDINALITY key_id
      LEFT JOIN games ON games.id=key_id
    ORDER BY ordinality`, [ids])
    return games.map(game => game.data)
  }
}

export class GamePlatformsConnection {
  constructor(id_game, ids_platform) {
    this._id_game = id_game
    this._ids_platform = ids_platform
  }
  static __typename = 'GamePlatformsConnection'

  async edges(args, ctx) {
    return this._ids_platform.map(id_platform => GamePlatformEdge.gen(this._id_game, id_platform, ctx))
  }

  /*
  DL.cache connection ?

  fetch edgeids ?
  fetch edges AND DL.prime ?

  fetch only nodeids ? --loose edge data
  fetch nodes AND DL.prime ? --loose edge data
  */

  //FETCH EDGEIDS
  static async gen(id_game, ctx) {
    let ids = await ctx.dl.gameplatforms.load(id_game)
    return ids ? new GamePlatformsConnection(id_game, ids) : null
  }
  static async load(ids, ctx) {
    let gamesplatforms = await ctx.db.any(`
    SELECT array_remove(array_agg(game_platforms.id_platform),null) as edges_id
      FROM unnest(ARRAY[$1:csv]::integer[]) WITH ORDINALITY key_id
        LEFT JOIN game_platforms ON game_platforms.id_game=key_id
    GROUP BY ordinality, game_platforms.id_game ORDER BY ordinality`, [ids])

    return gamesplatforms.map(gameplatforms => gameplatforms.edges_id)
  }
}