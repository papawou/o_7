export const schema = `
type Lobby {
  id: ID!
  name: String!
  created_at: String!

  members: LobbyMembersConnection!
}

extend type Query {
  lobby(id: ID!): Lobby
}
`
export const resolvers = {
  Query: {
    lobby: async (obj, { id }, ctx, info) => {
      if (Lobby.decode(id) == '') {
        return null
      }
      return await Lobby.gen(ctx, Lobby.decode(id))
    }
  }
}

export class Lobby {
  constructor(lobby) {
    this._id = lobby.id
    this.name = lobby.name
    this.created_at = lobby.created_at

    this.id = Lobby.encode(lobby.id)
  }
  static __typename = 'Lobby'

  //fields
  async members(args, ctx) {
    return await FriendshipConnection.gen(ctx, this._id)
  }

  //fetch
  static async gen(ctx, id) {
    let lobby = await ctx.dl.lobby.load('' + id)
    return lobby ? new Lobby(lobby) : null
  }

  //dataloader
  static async load(ctx, ids) {
    let cids = ids.map(id => Lobby.encode(id))
    let cached_nodes = await ctx.redis.mget(cids)
    let pg_ids = []

    for (let i = 0; i < cached_nodes.length; i++) {
      if (cached_nodes[i] == null)
        pg_ids.push(ids[i])
      else
        cached_nodes[i] = JSON.parse(cached_nodes[i])
    }

    if (pg_ids.length > 0) {
      let pg_nodes = await ctx.db.any(`
        SELECT row_to_json(lobbys.*) as data
          FROM unnest(ARRAY[$1:csv]::integer[]) WITH ORDINALITY key_id
          LEFT JOIN lobbys ON lobbys.id=key_id
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
  static encode(id_lobby) {
    return Lobby.__typename + '_' + id_lobby
  }

  static decode(cid_lobby) {
    return cid_lobby.slice(Lobby.__typename.length + 1)
  }
}