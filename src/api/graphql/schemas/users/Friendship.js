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
  friendship_byUnique(id_userA: ID!, id_userB: ID!): Friendship
  friendship(id: ID!): Friendship
}
`

export const resolvers = {
  Query: {
    friendship_byUnique: (obj, { id_userA, id_userB }, ctx, info) => Friendship.gen(ctx, Friendship.encode(User.decode(id_userA), User.decode(id_userB))),
    friendship: (obj, { id }, ctx, info) => Friendship.gen(ctx, id)
  },
  FriendshipInterface: {
    __resolveType: (obj, args, ctx, info) => obj ? obj.__typename : null
  }
}

export class Friendship {
  constructor(friendship) {
    this._id_usera = friendship.id_usera
    this._id_userb = friendship.id_userb
    this.id = Friendship.encode(friendship.id_usera, friendship.id_userb)
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
  static async gen(ctx, id) {
    let friendship = await ctx.dl.friendship.load(id)
    return friendship ? new this(friendship) : null
  }

  //dataloader
  static async load(ctx, ids) {
    let cached_nodes = await ctx.redis.mget(ids)
    let pg_ids = { ids_userA: [], ids_userB: [] }

    for (let i = 0; i < cached_nodes.length; i++) {
      if (cached_nodes[i] == null) {
        let unique_id = Friendship.decode(ids[i])
        pg_ids.ids_userA.push(unique_id[0])
        pg_ids.ids_userB.push(unique_id[1])
      }
      else
        cached_nodes[i] = JSON.parse(cached_nodes[i])
    }

    if (pg_ids.ids_userA.length > 0) {
      let pg_nodes = await ctx.db.any(`
        SELECT row_to_json(friendships.*) as data
          FROM unnest(ARRAY[$1:csv]::integer[], ARRAY[$2:csv]::integer[]) WITH ORDINALITY key_id(id_usera, id_userb)
          LEFT JOIN friendships ON friendships.id_usera=key_id.id_usera AND friendships.id_userb=key_id.id_userb
          ORDER BY ordinality
        `, [pg_ids.ids_userA, pg_ids.ids_userB])

      let pg_map = new Map()
      for (let i = 0; i < cached_nodes.length; i++) {
        if (cached_nodes[i] == null) {
          if (pg_nodes[0].data !== null) {
            pg_map.set(ids[i], JSON.stringify(pg_nodes[0].data))
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
  static encode(id_userA, id_userB) {
    return Friendship.__typename + '_' + (id_userA < id_userB ? id_userA + '-' + id_userB : id_userB + '-' + id_userA)
  }
  static decode(cid) {
    return cid.slice(Friendship.__typename.length + 1).split('-')
  }
}

class FriendshipEdge extends Friendship {
  constructor(friendship) {
    super(friendship)
    this._id_node = null
  }
  static __typename = 'FriendshipEdge'

  //fields
  async node(args, ctx) {
    return User.gen(ctx, this._id_node)
  }

  //fetch
  static async gen(ctx, viewed_as, id_friend) {
    let friendshipedge = await super.gen(ctx, Friendship.encode(viewed_as, id_friend))
    friendshipedge._id_node = viewed_as == friendshipedge._id_usera ? friendshipedge._id_userb : friendshipedge._id_usera
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
    let ids_friend = await ctx.dl.friendships.load('' + id_user)
    return new FriendshipConnection(id_user, ids_friend)
  }

  //dataloader
  static async load(ctx, ids) {
    let cids = ids.map(id => FriendshipConnection.encode(id))
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
        SELECT array_remove(array_agg(CASE WHEN friendships.id_usera = key_id THEN id_userb ELSE id_usera END), null) as data
          FROM unnest(ARRAY[$1:csv]::integer[]) WITH ORDINALITY key_id
          LEFT JOIN friendships ON friendships.id_usera=key_id OR friendships.id_userb=key_id
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
  static encode(id_user) {
    return FriendshipConnection.__typename + '_' + id_user
  }

  static decode(cid) {
    return cid.slice(FriendshipConnection.__typename.length + 1)
  }
}