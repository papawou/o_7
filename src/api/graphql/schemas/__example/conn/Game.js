export const schema = `
type Game {
  id: ID!
  name: String!

  platforms: [Platform]!
}
type Platform {
  id: ID!
  name: String!
}

type GamePlatformsConnection{
  edges: [GamePlatformEdge]!
}
type GamePlatformEdge implements GamePlatformInterface {
  game: Game!
  platform: Platform!
  cross: GameCross

  node: Platform!
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

  /*
  nodes: [Node]
  nodes: Conn.edges: [NodeEdge]
  nodes: [NodeEdge]

  DB->ids
    gen id
  DB->nodes
    primeBynode  loadByid
    genBynode

  DL->ids
    primeIds genById
  DL->node
    primeNode genById
    genByNode

  gen id
  gen node
  */
  async platforms(args, ctx) {
    let id_platforms = await db.any(`
    SELECT array_remove(array_agg(game_platforms.id_platform), null) as data
      FROM unnest(ARRAY[1,5]::integer[]) WITH ORDINALITY key_id
      LEFT JOIN game_platforms ON game_platforms.id_game=key_id
    GROUP BY ordinality, game_platforms.id_game ORDER BY ordinality;
    `)
    return await id_platforms.map(id_platform => Platform.gen(id_platform, ctx))
  }

  static async gen(id, ctx) {
    let game = await ctx.dl.game.load(parseInt(id))
    return game ? new Game(game) : null
  }
  static async load(ids, db) {
    let games = await db.any(`
    SELECT row_to_json(games.*) as data
    FROM unnest(ARRAY[$1:csv]::integer[]) WITH ORDINALITY key_id LEFT JOIN games ON games.id=key_id
    ORDER BY ordinality`, [ids])
    return games.map(game => game.data)
  }
}

export class Platform {
  constructor(platform) {
    this.id = platform.id
    this.name = platform.name
  }
  static __typename = 'Platform'

  static async gen(id, ctx) {
    let platform = await ctx.dl.platform.load(parseInt(id))
    return platform ? new Platform(platform) : null
  }
  static async load(ids, db) {
    let platforms = await db.any(`
    SELECT row_to_json(platforms.*) as data
    FROM unnest(ARRAY[$1:csv]::integer[]) WITH ORDINALITY key_id LEFT JOIN platforms ON platforms.id=key_id
    ORDER BY ordinality`, [ids])
    return platforms.map(platform => platform.data)
  }
}

export class GamePlatformsConnection {
  constructor(gameplatforms, id_game) {
    this._id_game = id_game
    this._ids_gameplatforms = gameplatforms
  }

  edges(args, ctx) {
    return this._ids_gameplatforms.map(_id_gameplatform => GamePlatformEdge.gen(_id_gameplatform.id_game, _id_gameplatform.id_platform, ctx))
  }

  static async gen(id_game, ctx) {
  }

  static async load(ids, db) {
    let lobbysmembers = await db.any(`
    SELECT COALESCE(json_agg(gameplatform.*) FILTER (WHERE lobby_members.id_user IS NOT NULL), '[]') as data
    FROM unnest(ARRAY[$1:csv]::integer[]) WITH ORDINALITY key_id LEFT JOIN game_platforms ON game_platforms.id_lobby=key_id
    GROUP BY ordinality, lobby_members.id_lobby
    ORDER BY ordinality`, [ids])
    return lobbysmembers.map(lobbymembers => lobbymembers.data)
  }
}