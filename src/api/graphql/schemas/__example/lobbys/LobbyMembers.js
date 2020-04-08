import { User } from "../users/User"
import { Lobby } from "./Lobby"

export const schema = `
interface LobbyMemberInterface {
  user: User!
  lobby: Lobby!

  joined_at: String!
}

type LobbyMember implements LobbyMemberInterface {
  user: User!
  lobby: Lobby!
  
  joined_at: String!
}

type LobbyMemberEdge implements LobbyMemberInterface{
  node: User!

  user: User!
  lobby: Lobby!
  
  joined_at: String!
}

type LobbyMembersConnection {
  edges: [LobbyMemberEdge]!
}
`

export const resolvers = {
  LobbyMemberInterface: {
    __resolveType: (obj, args, ctx, info) => {
      obj ? obj.__typename : null
    }
  }
}

export class LobbyMember {
  constructor(lobbymember) {
    this._id_lobby = lobbymember.id_lobby
    this._id_user = lobbymember.id_user
    this.joined_at = lobbymember.joined_at
  }
  static __typename = 'LobbyMember'

  async user(args, ctx) {
    return await User.gen(this._id_user, ctx)
  }
  async lobby(args, ctx) {
    return await Lobby.gen(this._id_lobby, ctx)
  }

  static async genByUser(id_user, ctx) {
    let lobbymember = await ctx.dl.lobbymemberByUser.load(parseInt(id_user))
    return lobbymember ? new this(lobbymember) : null
  }

  static async loadByUser(ids, db) {
    let lobbymembers = await db.any(`
    SELECT row_to_json(lobby_members.*) as data
    FROM unnest(ARRAY[$1:csv]::integer[]) WITH ORDINALITY key_id
      LEFT JOIN lobby_members ON lobby_members.id_user=key_id
    ORDER BY ordinality`, [ids])
    return lobbymembers.map(lobbymember => lobbymember.data)
  }

  /*
  static async genByUnique(id_lobby, id_user, ctx) {
    let lobbymember = await ctx.dl.lobbymemberByUnique.load({ id_lobby: parseInt(id_lobby), id_user: parseInt(id_user) })
    ctx.dl.lobbymemberByUser.prime(lobbymember.id_user, lobbymember)
    return lobbymember ? new this(lobbymember) : null
  }
  static async loadByUnique(ids, db) {
    let ids_lobby = []
    let ids_user = []
    for (let unique_id of ids) {
      ids_lobby.push(unique_id.id_lobby)
      ids_user.push(unique_id.id_user)
    }

    let lobbymembers = await db.any(`
    SELECT row_to_json(lobby_members.*) as data
    FROM unnest(ARRAY[$1:csv]::integer[], ARRAY[$2:csv]::integer[]) WITH ORDINALITY key_id(id_lobby, id_user)
        LEFT JOIN lobby_members ON lobby_members.id_lobby=key_id.id_lobby AND lobby_members.id_user=key_id.id_user
    ORDER BY ordinality
    `, [ids_lobby, ids_user])
    return lobbymembers.map(lobbymember => lobbymember.data)
  }
  */
}

class LobbyMemberEdge extends LobbyMember {
  constructor(lobbymember) {
    super(lobbymember)
  }
  static __typename = 'LobbyMemberEdge'

  async node(args, ctx) {
    return await User.gen(this._id_user, ctx)
  }
}

export class LobbyMembersConnection {
  constructor(lobbymembers, id_lobby) {
    this._ids_lobbymembers = lobbymembers
    this._id_lobby = id_lobby
  }
  static __typename = 'LobbyMembersConnection'

  edges(args, ctx) {
    return this._ids_lobbymembers.map(_id_user => LobbyMemberEdge.genByUser(_id_user, ctx))
  }
  //note HOW TO ENSURE _ids_lobbymembers gen apart still part of lobby ? when no prime
  static async gen(id, ctx) {
    let lobbymembers = await ctx.dl.lobbymembers.load(parseInt(id))
    let _ids_lobbymembers = lobbymembers.map(lobbymember => {
      ctx.dl.lobbymemberByUser.prime(lobbymember.id_user, lobbymember)
      return lobbymember.id_user
    })

    return lobbymembers ? new LobbyMembersConnection(_ids_lobbymembers, parseInt(id)) : null
  }
  /*
  //RETURN [[ids_user]]
  static async load(ids, db) {
    let lobbysmembers = await db.any(`
    SELECT array_remove(array_agg(lobby_members.id_user), null) as data
    FROM unnest(ARRAY[$1:csv]::integer[]) WITH ORDINALITY key_id LEFT JOIN lobby_members ON lobby_members.id_lobby=key_id
    GROUP BY ordinality, lobby_members.id_lobby
    ORDER BY ordinality`, [ids])
    return lobbysmembers.map(lobbymembers => lobbymembers.data)
  }
  */

  //RETURN [[<lobbymember>],[]]
  static async load(ids, db) {
    let lobbysmembers = await db.any(`
    SELECT COALESCE(json_agg(lobby_members) FILTER (WHERE lobby_members.id_user IS NOT NULL), '[]') as data
    FROM unnest(ARRAY[$1:csv]::integer[]) WITH ORDINALITY key_id LEFT JOIN lobby_members ON lobby_members.id_lobby=key_id
    GROUP BY ordinality, lobby_members.id_lobby
    ORDER BY ordinality`, [ids])
    return lobbysmembers.map(lobbymembers => lobbymembers.data)
  }
}