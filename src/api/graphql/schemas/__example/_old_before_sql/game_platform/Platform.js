import { PlatformGameEdge, GamePlatform } from "./GamePlatform"

export const schema = `
type Platform {
  id: ID!
  name: String!
  
  game(id: ID!): GamePlatform
  games: PlatformGamesConnection
}

type PlatformGamesConnection {
  edges: [PlatformGameEdge]!
}

extend type Query {
  platform(id: ID!): Platform
}`

export const resolvers = {
  Query: {
    platform: (obj, { id }, ctx, info) => Platform.gen(id, ctx)
  }
}

export class Platform {
  constructor(platform) {
    this.id = platform.id
    this.name = platform.name
  }
  static __typename = 'Platform'

  async games(args, ctx) {
    return PlatformGamesConnection.gen(this.id, ctx)
  }
  async game({ id }, ctx) {
    return GamePlatform.gen(id, this.id)
  }

  static async gen(id, ctx) {
    let platform = await ctx.dl.platform.load(parseInt(id))
    return platform ? new Platform(platform) : null
  }
  static async load(ids, ctx) {
    let platforms = await ctx.db.any(`
    SELECT row_to_json(platforms.*) as data
    FROM unnest(ARRAY[$1:csv]::integer[]) WITH ORDINALITY key_id LEFT JOIN platforms ON platforms.id=key_id
    ORDER BY ordinality`, [ids])
    return platforms.map(platform => platform.data)
  }
}

export class PlatformGamesConnection {
  constructor(id_platform, ids_game) {
    this._id_platform = id_platform
    this._ids_game = ids_game
  }
  static __typename = 'PlatformGamesConnection'

  async edges(args, ctx) {
    return this._ids_game.map(id_game => PlatformGameEdge.gen(id_game, this._id_platform, ctx))
  }

  //FETCH EDGEIDS
  static async gen(id_platform, ctx) {
    let ids = await ctx.dl.platformgames.load(id_platform)
    return ids ? new PlatformGamesConnection(id_platform, ids) : null
  }
  static async load(ids, ctx) {
    let platformsgames = await ctx.db.any(`
    SELECT array_remove(array_agg(game_platforms.id_game),null) as edges_id
      FROM unnest(ARRAY[$1:csv]::integer[]) WITH ORDINALITY key_id
        LEFT JOIN game_platforms ON game_platforms.id_platform=key_id
    GROUP BY ordinality, game_platforms.id_platform ORDER BY ordinality`, [ids])

    return platformsgames.map(platformgames => platformgames.edges_id)
  }
}