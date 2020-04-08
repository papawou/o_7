import { User } from "../users/User"
import { LobbyMembersConnection } from "./LobbyMember"
import { Game } from "../game_platform/Game"
import { GameCross, GamePlatform } from "../game_platform/GamePlatform"

export const schema = `
union LobbyPlatforms = GamePlatform | GameCross
type Lobby {
  id: ID!
  owner: User!
  created_at: String!
  members: LobbyMembersConnection!

  game: Game
  platforms: LobbyPlatforms
}

extend type Query {
  lobby(id: ID!): Lobby
}
`

export const resolvers = {
  Query: {
    lobby: (obj, { id }, ctx, info) => Lobby.gen(id, ctx)
  },
  LobbyPlatforms: {
    __resolveType: (obj, args, ctx, info) => obj ? obj.__typename : null
  }
}

export class Lobby {
  constructor(lobby) {
    this.id = lobby.id
    this._id_owner = lobby.id_owner
    this._id_game = lobby.id_game
    this._id_platform = lobby.id_platform
    this._id_cross = lobby.id_cross

    this.created_at = lobby.created_at
  }
  static __typename = 'Lobby'

  async owner(args, ctx, info) {
    return await User.gen(this._id_owner, ctx)
  }
  async members(args, ctx) {
    return await LobbyMembersConnection.gen(this.id, ctx)
  }
  async game(args, ctx) {
    return await Game.gen(this._id_game, ctx)
  }
  async platforms(args, ctx) {
    return this._id_cross ?
      await GameCross.gen(this._id_game, this._id_cross, ctx)
      : await GamePlatform.gen(this._id_game, this._id_platform, ctx)
  }

  static async gen(id, ctx) {
    let lobby = await ctx.dl.lobby.load(parseInt(id))
    return lobby ? new Lobby(lobby) : null
  }
  static async load(ids, ctx) {
    let lobbys = await ctx.db.any(`
    SELECT row_to_json(lobbys.*) as data
    FROM unnest(ARRAY[$1:csv]::integer[]) WITH ORDINALITY key_id LEFT JOIN lobbys ON lobbys.id=key_id
    ORDER BY ordinality`, [ids])
    return lobbys.map(lobby => lobby.data)
  }
}