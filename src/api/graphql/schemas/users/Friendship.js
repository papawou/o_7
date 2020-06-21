import { User } from "./User"
import { utils } from "pg-promise"

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

type FriendshipEdge implements FriendshipInterface {
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
    friendship: (obj, { id_userA, id_userB }, ctx, info) => Friendship.gen(ctx, id_userA, id_userB),
  },
  FriendshipInterface: {
    __resolveType: (obj, args, ctx, info) => obj ? obj.__typename : null
  }
}

export class Friendship {
  constructor(friendship) {
    this._id_usera = friendship.id_usera
    this._id_userb = friendship.id_userb
  }
  static __typename = 'Friendship'

  //fields
  async userA(args, ctx) {
    return await User.gen(ctx, this._id_usera)
  }

  async userB(args, ctx) {
    return await User.gen(ctx, this._id_userb)
  }

  //fetch
  static async gen(ctx, id_usera, id_userb) {
    let friendship = await ctx.dl.friendship.load(JSON.stringify({ id_usera: Math.min(id_usera, id_userb), id_userb: Math.max(id_usera, id_userb) }))
    return friendship ? new this(friendship) : null
  }

  //dataloader
  static async load(ctx, ids) {
    "FR_xxxxxxxx"
    let ids_usera = []
    let ids_userb = []
    for (let unique_id of ids) {
      unique_id = JSON.parse(unique_id)
      ids_usera.push(unique_id.id_usera)
      ids_userb.push(unique_id.id_userb)
    }

    let friendships = await ctx.db.any(`
      SELECT row_to_json(friendships.*) as data
        FROM unnest(ARRAY[$1:csv]::integer[], ARRAY[$2:csv]::integer[]) WITH ORDINALITY key_id(id_usera, id_userb)
        LEFT JOIN friendships ON friendships.id_usera=key_id.id_usera AND friendships.id_userb=key_id.id_userb
        ORDER BY ordinality
    `, [ids_usera, ids_userb])

    return friendships.map(friendship => friendship.data)
  }

  static prime(ctx, friendship) {
    ctx.dl.friendship.prime({ id_usera: friendship.id_usera, id_userb: friendship.id_userb }, friendship)
  }

  static btoa(id_userA, id_userB) {
    return Buffer.from(`${this.__typename}_${id_userA}:${id_userB}`, 'base64').replace(/+/g, '-').replace(/=/g, '').replace(/\//g, '_')
  }
  static atob(base) {
    return Buffer.from(base.replace(/-/g, '+').replace(/_/g, '/'), 'utf8')
  }
}

class FriendshipEdge extends Friendship {
  constructor(friendship) {
    super(friendship)
  }
  static __typename = 'FriendshipEdge'

  //fields
  async node(args, ctx) {
    return User.gen(ctx, this._id_userb)
  }

  //fetch
  static async gen(ctx, viewed_as, id_friend) {
    let friendshipedge = await super.gen(ctx, viewed_as, id_friend)

    if (friendshipedge._id_userb == viewed_as) {
      friendshipedge._id_userb = friendshipedge._id_usera
      friendshipedge._id_usera = viewed_as
    }
    return friendshipedge
  }
}

export class FriendshipConnection {
  constructor(viewed_as, ids_friend) {
    this._viewed_as = viewed_as
    this._ids_friend = ids_friend
    this.count = ids_friend.length
  }
  static __typename = 'FriendshipConnection'

  //fields
  async edges(args, ctx) {
    return await Promise.all(this._ids_friend.map(async id_friend => await FriendshipEdge.gen(ctx, this._viewed_as, id_friend)))
  }

  //fetch
  static async gen(ctx, id_user) {
    let ids_friend = await ctx.dl.friendships.load(parseInt(id_user))
    return ids_friend ? new FriendshipConnection(id_user, ids_friend) : null
  }

  //dataloader
  static async load(ctx, ids) {
    let friendships = await ctx.db.any(`
      SELECT array_remove(array_agg(CASE WHEN friendships.id_usera = key_id THEN id_userb ELSE id_usera END), null) as data
        FROM unnest(ARRAY[$1:csv]::integer[]) WITH ORDINALITY key_id
        LEFT JOIN friendships ON friendships.id_usera=key_id OR friendships.id_userb=key_id
        GROUP BY ordinality ORDER BY ordinality;
    `, [ids])

    return friendships.map(({ data }) => data)
  }
}