import { FriendshipConnection } from "./Friendship"

export const schema = `
type User {
  id: ID!
  name: String!
  created_at: String!

  friends: FriendshipConnection!
}

extend type Query {
  user(id: ID!): User
}
`
export const resolvers = {
  Query: {
    user: (obj, { id }, ctx, info) => User.gen(ctx, id)
  }
}

export class User {
  constructor(user) {
    this.id = user.id
    this.name = user.name
    this.created_at = user.created_at
  }
  static __typename = 'User'

  //fields
  async friends(args, ctx) {
    return await FriendshipConnection.gen(ctx, this.id)
  }

  //fetch
  static async gen(ctx, id) {
    let user = await ctx.dl.user.load(parseInt(id))
    return user ? new User(user) : null
  }

  //dataloader
  static async load(ctx, ids) {
    let users = await ctx.db.any(`
      SELECT row_to_json(users.*) as data
        FROM unnest(ARRAY[$1:csv]::integer[]) WITH ORDINALITY key_id
        LEFT JOIN users ON users.id=key_id
        ORDER BY ordinality
    `, [ids])
    return users.map(user => user.data)
  }

  static prime(ctx, user) {
    ctx.dl.user.prime(user.id, user)
  }
}