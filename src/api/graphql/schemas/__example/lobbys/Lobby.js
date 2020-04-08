import { User } from "../users/User"
import { LobbyMembersConnection } from "./LobbyMembers"

export const schema = `
type Lobby {
  id: ID!
  owner: User!
  created_at: String!

  members: LobbyMembersConnection!
}

extend type Query {
  lobby(id: ID!): Lobby
}
`

export const resolvers = {
  Query: {
    lobby: (obj, { id }, ctx, info) => Lobby.gen(id, ctx)
  }
}

export class Lobby {
  constructor(lobby) {
    this.id = lobby.id
    this._id_owner = lobby.id_owner
    this.created_at = lobby.created_at
  }
  static __typename = 'Lobby'

  async owner(args, ctx, info) {
    return await User.gen(this._id_owner, ctx)
  }
  async members(args, ctx) {
    return await LobbyMembersConnection.gen(this.id, ctx)
  }

  static async gen(id, ctx) {
    let lobby = await ctx.dl.lobby.load(parseInt(id))
    return lobby ? new Lobby(lobby) : null
  }
  static async load(ids, db) {
    let lobbys = await db.any(`
    SELECT row_to_json(lobbys.*) as data
    FROM unnest(ARRAY[$1:csv]::integer[]) WITH ORDINALITY key_id LEFT JOIN lobbys ON lobbys.id=key_id
    ORDER BY ordinality`, [ids])
    return lobbys.map(lobby => lobby.data)
  }
}