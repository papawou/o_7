export const schema = `
input LobbyInput_create {
  id_game: ID!
  id_platform: ID!
  id_cross: ID = null
  max_size: Int!
}

input LobbyInput_join {
  id_lobby: ID!
  id_cv: ID = null
}

extend type Mutation {
  lobby_create(input: LobbyInput_create!): ID!
  lobby_join(input: LobbyInput_join!): ID!
  lobby_leave: ID!
  lobby_kickmember(id_user: ID!): Boolean
}
`

export const resolvers = {
  Mutation: {
    lobby_create: async (obj, { input }, ctx, info) => {
      if (!ctx.viewer)
        return null
      input.id_viewer = ctx.viewer.id
      return await ctx.db.one("SELECT * FROM lobby_create(${id_viewer}, ${id_game}, ${id_platform}, ${id_cross}, ${max_size})", input, a => a.id_lobby_)
    },
    lobby_join: async (obj, { input }, ctx, info) => {
      if (!ctx.viewer)
        return null
      input.id_viewer = ctx.viewer.id
      return await ctx.db.one("SELECT * FROM lobby_join(${id_viewer}, ${id_lobby}, ${id_cv})", input, a => a.success_)
    },
    lobby_leave: async (obj, args, ctx, info) => {
      if (!ctx.viewer)
        return null
      return await ctx.db.proc("lobby_leave", [ctx.viewer.id], a => a.id_lobby_)
    },
    lobby_kickmember: async (obj, args, ctx, info) => {
      if (!ctx.viewer)
        return null
    }
  }
}