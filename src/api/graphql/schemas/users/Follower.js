import { User } from "./User"

export const schema = `
interface FollowerInterface {
  follower: User!
  following: User!

  created_at: String!
}

type Follower implements FollowerInterface {
  follower: User!
  following: User!

  created_at: String!
}

type FollowerEdge implements FollowerInterface{
  node: User!

  follower: User!
  following: User!

  created_at: String!
}

type FollowerConnection {
  edges: [FollowerEdge]!
  count: Int!
}

extend type Query {
  follower(id_follower: ID!, id_following: ID!): Follower
}
`

export const resolvers = {
  Query: {
    follower: (obj, { id_follower, id_following }, ctx, info) => Follower.gen(id_follower, id_following, ctx)
  }
}

export class Follower {
  constructor(follower) {
    this._id_follower = follower.id_follower
    this._id_following = follower.id_following
  }
  static __typename = 'Follower'

  async follower(args, ctx) {
    return await User.gen(this._id_follower, ctx)
  }

  async following(args, ctx) {
    return await User.gen(this._id_following, ctx)
  }

  static async gen(_id_follower, _id_following, ctx) {
    let follower = await ctx.dl.follower.load({ id_follower: id_follower, id_following: id_following })
    return follower ? new Follower(follower) : null
  }

  //dataloader
  static async load(ids, db) {
    let ids_follower = []
    let ids_following = []
    for (let unique_id of ids) {
      ids_follower.push(unique_id.id_follower)
      ids_following.push(unique_id.id_following)
    }

    let followers = await db.any(`
    SELECT row_to_json(user_followers) as data
    FROM unnest(ARRAY[$1:csv]::integer[], ARRAY[$2:csv]::integer[]) WITH ORDINALITY key_id(id_follower, id_following)
        LEFT JOIN user_followers ON user_followers.id_follower=key_id.id_follower AND user_friends.id_following=key_id.id_following
    ORDER BY ordinality
    `, [ids_follower, ids_following])
    return followers.map(follower => follower.data)
  }
  static prime(follower, ctx) {
    ctx.dl.follower.prime({ id_follower: follower.id_follower, id_following: follower.id_following }, follower)
  }
}

class FollowerEdge extends Follower {
  constructor(follower, viewed_as) {
    super(follower)
  }
  static __typename = 'FollowerEdge'

  async node(args, ctx) {
    return User.gen(this._id_follower, ctx)
  }
}

export class FollowerConnection {
  constructor(viewed_as, ids_friend) {
    this._viewed_as = viewed_as
    this._ids_friend = ids_friend
    this.count= ids_friend.length
  }
  static __typename = 'FollowerConnection'

  async edges(args, ctx) {
    return this._ids_friend.map(id_friend => FollowerEdge.gen(id_friend, viewed_as, ctx))
  }

  static async gen(id_user, ctx) {
    let ids_friend = await ctx.dl.followers.load(parseInt(id_user))
    return ids_friend ? new FollowerConnection(id_user, ids_friend) : null
  }
  static async load(ids, ctx) {
    let followers = await ctx.db.any(`
    SELECT key_id, COALESCE(json_agg(user_friends) FILTER (WHERE user_friends.id_userA IS NOT NULL), '[]') as data
      FROM unnest(ARRAY[$1:csv]::integer[]) WITH ORDINALITY key_id
      LEFT JOIN user_friends ON user_friends.id_userA=key_id OR user_friends.id_userB=key_id
    GROUP BY ordinality, key_id ORDER BY ordinality`, [ids])

    return followers.map(({key_id, data }) => data.map(follower => {
      Follower.prime(follower, ctx)
      return follower.id_userA = key_id ? follower.id_userB : follower.id_userA
    }))
  }
}