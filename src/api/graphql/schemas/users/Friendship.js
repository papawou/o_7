import { User } from "./User"

export const schema = `
interface FriendshipInterface {
  userA: User!
  userB: User!

  created_at: String!
}

type Friendship implements FriendshipInterface {
  userA: User!
  userB: User!
  
  created_at: String!
}

type FriendshipEdge implements FriendshipInterface{
  node: User!

  userA: User!
  userB: User!

  created_at: String!
}

type FriendshipConnection {
  edges: [FriendshipEdge]!
  count: Int!
}

extend type Query {
  friendship(id_userA: ID!, id_userB: ID!): Friendship
}
`

export const resolvers = {
  Query: {
    friendship: (obj, { id_userA, id_userB }, ctx, info) => Friendship.gen(id_userA, id_userB, ctx)
  }
}

export class Friendship {
  constructor(friendship) {
    this._id_userA = friendship.id_userA
    this._id_userB = friendship.id_userB
  }
  static __typename = 'Friendship'

  async userA(args, ctx) {
    return await User.gen(this._id_userA, ctx)
  }

  async userB(args, ctx) {
    return await User.gen(this._id_userB, ctx)
  }

  static async gen(id_userA, id_userB, ctx) {
    let friendship = await ctx.dl.friendship.load({ id_userA: Math.min(id_userA, id_userB), id_userB: Math.max(id_userA, id_userB) })
    return friendship ? new Friendship(friendship) : null
  }

  //dataloader
  static async load(ids, db) {
    let ids_userA = []
    let ids_userB = []
    for (let unique_id of ids) {
      ids_userA.push(unique_id.id_userA)
      ids_userB.push(unique_id.id_userB)
    }

    let friendships = await db.any(`
    SELECT row_to_json(user_friends) as data
    FROM unnest(ARRAY[$1:csv]::integer[], ARRAY[$2:csv]::integer[]) WITH ORDINALITY key_id(id_userA, id_userB)
        LEFT JOIN user_friends ON user_friends.id_userA=key_id.id_userA AND user_friends.id_userB=key_id.id_userB
    ORDER BY ordinality
    `, [ids_userA, ids_userB])
    return friendships.map(friendship => friendship.data)
  }
  static prime(friendship, ctx) {
    ctx.dl.friendship.prime({ id_userA: friendship.id_userA, id_userB: friendship.id_userB }, friendship)
  }
}

class FriendshipEdge extends Friendship {
  constructor(friendship, viewed_as) {
    super(friendship)
    this._viewed_as = viewed_as
  }
  static __typename = 'FriendshipEdge'

  static async gen(id_userA, id_userB, viewed_as, ctx) {
    return new FriendshipEdge(await Friendship.gen(id_userA,id_userB), viewed_as)
  }

  async node(args, ctx) {
    return User.gen(this._id_userA = viewed_as ? this._id_userB : this._id_userA, ctx)
  }
}

export class FriendshipConnection {
  constructor(viewed_as, ids_friend) {
    this._viewed_as = viewed_as
    this._ids_friend = ids_friend
    this.count = ids_friend.length
  }
  static __typename = 'FriendshipConnection'

  async edges(args, ctx) {
    return this._ids_friend.map(id_friend => FriendshipEdge.gen(id_friend, viewed_as, ctx))
  }

  static async gen(id_user, ctx) {
    let ids_friend = await ctx.dl.friendships.load(parseInt(id_user))
    return ids_friend ? new FriendshipConnection(id_user, ids_friend) : null
  }
  static async load(ids, ctx) {
    let friendships = await ctx.db.any(`
    SELECT key_id, COALESCE(json_agg(user_friends) FILTER (WHERE user_friends.id_userA IS NOT NULL), '[]') as data
      FROM unnest(ARRAY[$1:csv]::integer[]) WITH ORDINALITY key_id
      LEFT JOIN user_friends ON user_friends.id_userA=key_id OR user_friends.id_userB=key_id
    GROUP BY ordinality, key_id ORDER BY ordinality`, [ids])

    return friendships.map(({key_id, data }) => data.map(friendship => {
      Friendship.prime(friendship, ctx)
      return friendship.id_userA = key_id ? friendship.id_userB : friendship.id_userA
    }))
  }
}