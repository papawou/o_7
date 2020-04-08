export const schema = `
type AuthLobby {
  is_owner: Boolean!
  is_member: Boolean!
}

extend type Query {
  authlobby(id_user: ID!, id_lobby: ID!): AuthLobby!
}
`

export const resolvers = {
  Query: {
    authlobby: (obj, { id_user, id_lobby }, ctx, info) => {
      return true
    }
  }
}

export class AuthLobby {
  constructor(authlobby) {
    this.is_member = authlobby.is_member
    this.is_owner = authlobby.is_owner
  }

  static async gen(id_user, id_lobby, ctx) {
    let authlobby = await ctx.dl.authlobby.load({ id_user: id_user, id_lobby: id_lobby })
    return new AuthLobby(authlobby)
  }

  static async load(ids, ctx) {
  }
}