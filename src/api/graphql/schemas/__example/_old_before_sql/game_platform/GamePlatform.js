import { Game } from "./Game"
import { Platform } from "./Platform"

export const schema = `
interface GamePlatformInterface {
  game: Game!
  platform: Platform!
  cross: GameCross
}

type GamePlatform implements GamePlatformInterface {
  game: Game!
  platform: Platform!
  cross: GameCross
}
type GamePlatformEdge implements GamePlatformInterface {
  node: Platform!

  game: Game!
  platform: Platform!
  cross: GameCross!
}
type PlatformGameEdge implements GamePlatformInterface {
  node: Game!

  game: Game!
  platform: Platform!
  cross: GameCross
}

type GameCross {
  id_cross: ID!
  game: Game!
  platforms: [Platform]!
}
`

export const resolvers = {
  GamePlatformInterface: {
    __resolveType: (obj, args, ctx, info) => obj ? obj.__typename : null
  }
}

export class GamePlatform {
  constructor(gameplatform) {
    this._id_cross = gameplatform.id_cross
    this._id_game = gameplatform.id_game
    this._id_platform = gameplatform.id_platform
  }
  static __typename = 'GamePlatform'

  async game(args, ctx) {
    return Game.gen(this._id_game, ctx)
  }
  async platform(args, ctx) {
    return Platform.gen(this._id_platform, ctx)
  }
  async cross(args, ctx) {
    return this._id_cross ? GameCross.gen(this._id_game, this._id_cross, ctx) : null
  }

  static async gen(id_game, id_platform, ctx) {
    let gameplatform = await ctx.dl.gameplatform.load({ id_game: parseInt(id_game), id_platform: parseInt(id_platform) })
    return gameplatform ? new this(gameplatform) : null
  }

  static async load(ids, ctx) {
    let ids_game = []
    let ids_platform = []
    for (let unique_id of ids) {
      ids_game.push(unique_id.id_game)
      ids_platform.push(unique_id.id_platform)
    }

    let gameplatforms = await ctx.db.any(`
    SELECT row_to_json(game_platforms.*) as data
    FROM unnest(ARRAY[$1:csv]::integer[], ARRAY[$2:csv]::integer[]) WITH ORDINALITY key_id(id_game, id_platform)
        LEFT JOIN game_platforms ON game_platforms.id_game=key_id.id_game AND game_platforms.id_platform=key_id.id_platform
    ORDER BY ordinality
    `, [ids_game, ids_platform])
    return gameplatforms.map(gameplatform => gameplatform.data)
  }
  static prime(gameplatform, ctx) {
    ctx.dl.gameplatform.prime({ id_game: gameplatform.id_game, id_platform: gameplatform.id_platform }, gameplatform)
  }
}

//FETCH NODEIDS
export class GameCross {
  constructor(gamecross) {
    this.id_cross = gamecross.id_cross
    this._id_game = gamecross.id_game
    this._ids_platform = gamecross.ids_platform
  }
  static __typename = 'GameCross'

  async game(args, ctx) {
    return Game.gen(this._id_game, ctx)
  }
  async platforms(args, ctx) {
    return this._ids_platform.map(id_platform => Platform.gen(id_platform, ctx))
  }

  static async gen(id_game, id_cross, ctx) {
    let gamecross = await ctx.dl.gamecross.load({ id_game: parseInt(id_game), id_cross: parseInt(id_cross) })
    return gamecross ? new GameCross(gamecross) : null
  }
  static async load(ids, ctx) {
    let ids_game = []
    let ids_cross = []
    for (let unique_id of ids) {
      ids_game.push(unique_id.id_game)
      ids_cross.push(unique_id.id_cross)
    }

    let gamecrosses = await ctx.db.any(`
    SELECT game_platforms.id_game, game_platforms.id_cross, array_remove(array_agg(game_platforms.id_platform), null) as ids_platform
    FROM unnest(ARRAY[$1:csv]::integer[], ARRAY[$2:csv]::integer[]) WITH ORDINALITY key_id(id_game, id_cross)
        LEFT JOIN game_platforms ON game_platforms.id_game=key_id.id_game AND game_platforms.id_cross=key_id.id_cross
    GROUP BY ordinality, game_platforms.id_game, game_platforms.id_cross ORDER BY ordinality`, [ids_game, ids_cross])
    return gamecrosses.map(gamecross => gamecross.id_game ? gamecross : null)
  }
}

export class GamePlatformEdge extends GamePlatform {
  constructor(gameplatform) {
    super(gameplatform)
  }
  static __typename = 'GamePlatformEdge'

  async node(args, ctx) {
    return Platform.gen(this._id_platform, ctx)
  }
}

export class PlatformGameEdge extends GamePlatform {
  constructor(gameplatform) {
    super(gameplatform)
  }
  static __typename = 'PlatformGameEdge'

  async node(args, ctx) {
    return Game.gen(this._id_game, ctx)
  }
}