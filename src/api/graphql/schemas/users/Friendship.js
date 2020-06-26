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
    friendship: (obj, { id_userA, id_userB }, ctx, info) => Friendship.genByUnique(ctx, id_userA, id_userB),
  },
  FriendshipInterface: {
    __resolveType: (obj, args, ctx, info) => obj ? obj.__typename : null
  }
}

export class Friendship {
  constructor(friendship) {
    this._cid_usera = User.encode(friendship.id_usera)
    this._cid_userb = User.encode(friendship.id_userb)
    this.id = Friendship.encode(friendship.id_usera, friendship.id_userb)
  }
  static __typename = 'Friendship'

  //fields
  async userA(args, ctx) {
    return await User.gen(ctx, this._cid_usera)
  }

  async userB(args, ctx) {
    return await User.gen(ctx, this._cid_userb)
  }

  //fetch
  static async gen(ctx, cid) {
    let friendship = await ctx.dl.friendship.load(cid)
    return friendship ? new this(friendship) : null
  }
  static async genByUnique(ctx, cid_userA, cid_userB) {
    return await Friendship.gen(ctx, Friendship.encode(User.decode(cid_userA), User.decode(cid_userB)))
  }
  //utils
  static encode(id_userA, id_userB) {
    return Friendship.__typename + '_' + id_userA < id_userB ? id_userA + '-' + id_userB : id_userB + '-' + id_userA
  }
  static decode(cid) {
    return cid.slice(Friendship.__typename.length + 1).split('-')
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

    if (pg_ids.ids_userA > 0) {
      let pg_nodes = await ctx.db.any(`
        SELECT row_to_json(friendships.*) as data
          FROM unnest(ARRAY[$1:csv]::integer[], ARRAY[$2:csv]::integer[]) WITH ORDINALITY key_id(id_usera, id_userb)
          LEFT JOIN friendships ON friendships.id_usera=key_id.id_usera AND friendships.id_userb=key_id.id_userb
          ORDER BY ordinality
        `, [pg_ids.ids_userA, pg_ids.ids_userB])

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

class FriendshipEdge extends Friendship {
  constructor(friendship) {
    super(friendship)
    this._cid_node = null
  }
  static __typename = 'FriendshipEdge'

  //fields
  async node(args, ctx) {
    return User.gen(ctx, this._cid_node)
  }

  //fetch
  static async gen(ctx, viewed_as, cid_friend) {
    let friendshipedge = await super.genByUnique(ctx, viewed_as, cid_friend)
    friendshipedge._cid_node = viewed_as == friendshipedge._cid_usera ? friendshipedge._cid_userb : friendshipedge._cid_usera
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
    return await Promise.all(this._ids_friend.map(async id_friend => await FriendshipEdge.gen(ctx, this._viewed_as, User.encode(id_friend))))
  }

  //fetch
  static async gen(ctx, cid_user) {
    let ids_friend = await ctx.dl.friendships.load(cid_user)
    return new FriendshipConnection(cid_user, ids_friend)
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