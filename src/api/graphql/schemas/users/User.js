import { LobbyMember } from '../lobbys/LobbyMember'

export const schema = `
type User {
  id: ID!
  name: String!
  created_at: String!

  lobbyMember: LobbyMember
}

extend type Query {
  user(id: ID!): User
}
`

export class User {
  constructor(user) {
    this.id = user.id
    this.name = user.name
    this.created_at = user.created_at
  }
  static __typename = 'User'

  async lobbyMember(args, ctx) {
    return LobbyMember.genByUser(this.id, ctx)
  }

  static async gen(id, ctx) {
    let user = await ctx.dl.user.load(parseInt(id))
    return user ? new User(user) : null
  }
  static async load(ids, ctx) {
    let users = await ctx.db.any(`
    SELECT row_to_json(users.*) as data
    FROM unnest(ARRAY[$1:csv]::integer[]) WITH ORDINALITY key_id LEFT JOIN users ON users.id=key_id
    ORDER BY ordinality`, [ids])
    return users.map(user => user.data)
  }
}

export const resolvers = {
  Query: {
    user: (obj, { id }, ctx, info) => User.gen(id, ctx)
  }
}