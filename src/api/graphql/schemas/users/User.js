import { FriendshipConnection, Friendship } from "./Friendship"
import { FollowerConnection, FollowingConnection } from "./Follow"

export const schema = `
type User {
  id: ID!
  name: String!
  created_at: String!

  friends: FriendshipConnection!

  followers: FollowerConnection!
  followings: FollowingConnection!
}

extend type Query {
  user(id: ID!): User
}
`
export const resolvers = {
  Query: {
    user: async (obj, { id }, ctx, info) => await User.gen(ctx, id)
  }
}

export class User {
  constructor(user) {
    this.id = User.encode(user.id)
    this.name = user.name
    this.created_at = user.created_at
  }
  static __typename = 'User'

  //fields
  async friends(args, ctx) {
    return await FriendshipConnection.gen(ctx, this.id)
  }

  async followers(args, ctx) {
    return await FollowerConnection.gen(ctx, this.id)
  }

  async followings(args, ctx) {
    return await FollowingConnection.gen(ctx, this.id)
  }

  //fetch
  static async gen(ctx, cid) {
    let user = await ctx.dl.user.load(cid)
    return user ? new User(user) : null
  }

  //utils
  static encode(id_user) {
    return User.__typename + '_' + id_user
  }

  static decode(cid_user) {
    return cid_user.slice(User.__typename.length + 1)
  }

  //dataloader
  static async load(ctx, ids) {
    let cached_nodes = await ctx.redis.mget(ids)
    let pg_ids = []

    for (let i = 0; i < cached_nodes.length; i++) {
      if (cached_nodes[i] == null)
        pg_ids.push(User.decode(ids[i]))
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
      /*
      //init map with non null values
      let pg_map = new Map()
      for (let i = 0; i < pg_nodes.length; i++) {
        if (pg_nodes[i].data != null)
          pg_map.set(User.encode(pg_ids[i]), JSON.stringify(pg_nodes[i].data))
      }

      //mset map
      if (pg_map.size > 0) {
        await ctx.redis.mset(pg_map)

        for (let i = 0; i < cached_nodes.length; i++) {
          if (cached_nodes[i] == null)
            cached_nodes[i] = pg_nodes.shift().data
        }
      }*/
      let pg_map = new Map()
      for (let i = 0; i < cached_nodes.length; i++) {
        if (cached_nodes[i] == null && pg_nodes[0].data !== null) {
          pg_map.set(ids[i], pg_nodes[0].data)
          cached_nodes[i] = pg_nodes.shift().data
        }
      }
      await ctx.redis.mset(pg_map)
    }

    return cached_nodes
  }
}