export const schema = `
enum frienshiprequest_status {
  WAITING_TARGET
  DECLINED
}
type FriendshipRequest {
  id: ID!
  creator: User!
  target: User!

  status
}

extend type Query {
  user(id: ID!): User
}
`
export const resolvers = {
  Query: {
    user: async (obj, { id }, ctx, info) => {
      if (User.decode(id) == '') {
        return null
      }
      return await User.gen(ctx, User.decode(id))
    }
  },
  UserInterface: {
    __resolveType: (obj, args, ctx, info) => obj ? obj.__typename : null
  }
}

export class User {
  constructor(user) {
    this._id = user.id
    this.name = user.name
    this.created_at = user.created_at

    this.id = User.encode(user.id)
  }
  static __typename = 'User'

  //fields
  async friends(args, ctx) {
    return await FriendshipConnection.gen(ctx, this._id)
  }

  async followers(args, ctx) {
    return await FollowerConnection.gen(ctx, this._id)
  }

  async followings(args, ctx) {
    return await FollowingConnection.gen(ctx, this._id)
  }

  //fetch
  static async gen(ctx, id) {
    let user = await ctx.dl.user.load('' + id)
    return user ? new User(user) : null
  }

  //dataloader
  static async load(ctx, ids) {
    let cids = ids.map(id => User.encode(id))
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
        SELECT row_to_json(users.*) as data
          FROM unnest(ARRAY[$1:csv]::integer[]) WITH ORDINALITY key_id
          LEFT JOIN users ON users.id=key_id
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
  static encode(id_user) {
    return User.__typename + '_' + id_user
  }

  static decode(cid_user) {
    return cid_user.slice(User.__typename.length + 1)
  }
}