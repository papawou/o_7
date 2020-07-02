import { User } from "./User"

export const schema = `
interface FollowInterface {
  follower: User!
  following: User!

  created_at: String!
}

type Follow implements FollowInterface {
  follower: User!
  following: User!
  
  created_at: String!
}

type FollowerEdge implements FollowInterface {
  node: User!

  follower: User!
  following: User!

  created_at: String!
}

type FollowerConnection {
  edges: [FollowerEdge]!
  count: Int!
}

type FollowingEdge implements FollowInterface {
  node: User!

  follower: User!
  following: User!

  created_at: String!
}

type FollowingConnection {
  edges: [FollowingEdge]!
  count: Int!
}

extend type Query {
  follow(id_follower: ID!, id_following: ID!): Follow
}
`

export const resolvers = {
  Query: {
    follow: async (obj, { id_follower, id_following }, ctx, info) => await Follow.gen(ctx, User.decode(id_follower), User.decode(id_following)),
  },
  FollowInterface: {
    __resolveType: (obj, args, ctx, info) => obj ? obj.__typename : null
  }
}

export class Follow {
  constructor(follow) {
    this._id_follower = follow.id_follower
    this._id_following = follow.id_following

    this.id = Follow.encode(this._id_follower, this._id_following)
  }
  static __typename = 'Follow'

  //fields
  async follower(args, ctx) {
    return await User.gen(ctx, this._id_follower)
  }

  async following(args, ctx) {
    return await User.gen(ctx, this._id_following)
  }

  //fetch
  static async gen(ctx, id_follower, id_following) {
    let follow = await ctx.dl.follow.load(Follow.encode(id_follower, id_following))
    return follow ? new this(follow) : null
  }

  //dataloader
  static async load(ctx, cids) {
    let cached_nodes = await ctx.redis.mget(cids)
    let pg_ids = { ids_follower: [], ids_following: [] }

    for (let i = 0; i < cached_nodes.length; i++) {
      if (cached_nodes[i] == null) {
        let unique_id = Follow.decode(cids[i])
        pg_ids.ids_follower.push(unique_id[0])
        pg_ids.ids_following.push(unique_id[1])
      }
      else
        cached_nodes[i] = JSON.parse(cached_nodes[i])
    }

    if (pg_ids.ids_follower.length > 0) {
      let pg_nodes = await ctx.db.any(`
        SELECT row_to_json(follows.*) as data
          FROM unnest(ARRAY[$1:csv]::integer[], ARRAY[$2:csv]::integer[]) WITH ORDINALITY key_id(id_follower, id_following)
          LEFT JOIN follows ON follows.id_follower=key_id.id_follower AND follows.id_following=key_id.id_following
          ORDER BY ordinality
        `, [pg_ids.ids_follower, pg_ids.ids_following])

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
  static encode(id_follower, id_following) {
    return Follow.__typename + '_' + id_follower + '-' + id_following
  }
  static decode(cid) {
    return cid.slice(Follow.__typename.length + 1).split('-')
  }
}

class FollowerEdge extends Follow {
  constructor(follow) {
    super(follow)
  }
  static __typename = 'FollowerEdge'

  //fields
  async node(args, ctx) {
    return User.gen(ctx, this._id_follower)
  }
}

export class FollowerConnection {
  constructor(id_following, ids_follower) {
    this._id_following = id_following
    this._ids_follower = ids_follower
    this.count = ids_follower.length
  }
  static __typename = 'FollowerConnection'

  //fields
  async edges(args, ctx) {
    return await Promise.all(this._ids_follower.map(async id_follower => await FollowerEdge.gen(ctx, id_follower, this._id_following)))
  }

  //fetch
  static async gen(ctx, id_following) {
    let ids_follower = await ctx.dl.followers.load('' + id_following)
    return ids_follower ? new FollowerConnection(id_following, ids_follower) : null
  }

  //dataloader
  static async load(ctx, ids) {
    let cids = ids.map(id => FollowerConnection.encode(id))
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
        SELECT array_remove(array_agg(follows.id_follower), null) as data
          FROM unnest(ARRAY[$1:csv]::integer[]) WITH ORDINALITY key_id
          LEFT JOIN follows ON follows.id_following=key_id
          GROUP BY ordinality ORDER BY ordinality;
        `, [pg_ids])

      let pg_map = new Map()
      for (let i = 0; i < cached_nodes.length; i++) {
        if (cached_nodes[i] == null) {
          if (pg_nodes[0].data.length > 0) {
            pg_map.set(cids[i], JSON.stringify(pg_nodes[0].data))
          }
          cached_nodes[i] = pg_nodes.shift().data
        }
      }
      if (pg_map.size > 0)
        await ctx.redis.mset(pg_map)
    }

    return cached_nodes
  }

  //utils
  static encode(id_following) {
    return FollowerConnection.__typename + '_' + id_following
  }
  static decode(cid) {
    return cid.slice(FollowerConnection.__typename.length + 1)
  }
}

class FollowingEdge extends Follow {
  constructor(follow) {
    super(follow)
  }
  static __typename = 'FollowingEdge'

  //fields
  async node(args, ctx) {
    return User.gen(ctx, this._id_following)
  }
}

export class FollowingConnection {
  constructor(id_follower, ids_following) {
    this._id_follower = id_follower
    this._ids_following = ids_following
    this.count = ids_following.length
  }
  static __typename = 'FollowingConnection'

  //fields
  async edges(args, ctx) {
    return await Promise.all(this._ids_following.map(async id_following => await FollowingEdge.gen(ctx, this._id_follower, id_following)))
  }

  //fetch
  static async gen(ctx, id_follower) {
    let ids_following = await ctx.dl.followings.load('' + id_follower)
    return ids_following ? new FollowingConnection(id_follower, ids_following) : null
  }

  //dataloader
  static async load(ctx, ids) {
    let cids = ids.map(id => FollowingConnection.encode(id))
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
        SELECT array_remove(array_agg(follows.id_following), null) as data
          FROM unnest(ARRAY[$1:csv]::integer[]) WITH ORDINALITY key_id
          LEFT JOIN follows ON follows.id_follower=key_id
          GROUP BY ordinality ORDER BY ordinality;
        `, [pg_ids])

      let pg_map = new Map()
      for (let i = 0; i < cached_nodes.length; i++) {
        if (cached_nodes[i] == null) {
          if (pg_nodes[0].data.length > 0) {
            pg_map.set(cids[i], JSON.stringify(pg_nodes[0].data))
          }
          cached_nodes[i] = pg_nodes.shift().data
        }
      }

      if (pg_map.size > 0)
        await ctx.redis.mset(pg_map)
    }

    return cached_nodes
  }

  //utils
  static encode(id_follower) {
    return FollowingConnection.__typename + '_' + id_follower
  }
  static decode(cid) {
    return cid.slice(FollowingConnection.__typename + 1)
  }
}
