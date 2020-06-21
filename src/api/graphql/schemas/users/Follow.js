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
    follow: async (obj, { id_follower, id_following }, ctx, info) => await Follow.gen(ctx, id_follower, id_following),
  },
  FollowInterface: {
    __resolveType: (obj, args, ctx, info) => obj ? obj.__typename : null
  }
}

export class Follow {
  constructor(follow) {
    this._id_follower = follow.id_follower
    this._id_following = follow.id_following
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
    let follow = await ctx.dl.follow.load(JSON.stringify({ id_follower: id_follower, id_following: id_following }))
    return follow ? new this(follow) : null
  }

  //dataloader
  static async load(ctx, ids) {
    let ids_follower = []
    let ids_following = []
    for (let unique_id of ids) {
      unique_id = JSON.parse(unique_id)
      ids_follower.push(unique_id.id_follower)
      ids_following.push(unique_id.id_following)
    }

    let follows = await ctx.db.any(`
      SELECT row_to_json(follows.*) as data
        FROM unnest(ARRAY[$1:csv]::integer[], ARRAY[$2:csv]::integer[]) WITH ORDINALITY key_id(id_follower, id_following)
        LEFT JOIN follows ON follows.id_follower=key_id.id_follower AND follows.id_following=key_id.id_following
        ORDER BY ordinality
    `, [ids_follower, ids_following])

    return follows.map(follow => follow.data)
  }

  static prime(ctx, follow) {
    ctx.dl.follow.prime(JSON.stringify({ id_follower: follow.id_follower, id_following: follow.id_following }), follow)
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
    let ids_follower = await ctx.dl.followers.load(parseInt(id_following))
    return ids_follower ? new FollowerConnection(id_following, ids_follower) : null
  }

  //dataloader
  static async load(ctx, ids) {
    let followers = await ctx.db.any(`
      SELECT array_remove(array_agg(follows.id_follower), null) as data
        FROM unnest(ARRAY[$1:csv]::integer[]) WITH ORDINALITY key_id
        LEFT JOIN follows ON follows.id_following=key_id
        GROUP BY ordinality ORDER BY ordinality;
    `, [ids])

    return followers.map(({ data }) => data)
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
    let ids_following = await ctx.dl.followings.load(parseInt(id_follower))
    return ids_following ? new FollowingConnection(id_follower, ids_following) : null
  }

  //dataloader
  static async load(ctx, ids) {
    let followings = await ctx.db.any(`
      SELECT array_remove(array_agg(follows.id_following), null) as data
        FROM unnest(ARRAY[$1:csv]::integer[]) WITH ORDINALITY key_id
        LEFT JOIN follows ON follows.id_follower=key_id
        GROUP BY ordinality ORDER BY ordinality;
    `, [ids])

    return followings.map(({ data }) => data)
  }
}
