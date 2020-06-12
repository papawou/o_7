export const schema = `
enum LobbyPrivacy {
  PRIVATE
  FRIEND
  FOLLOWER
  GUEST
}

input LobbyInput_create {
  id_game: ID!
  id_platform: ID!
  id_cross: ID = null
  max_size: Int!
  privacy: LobbyPrivacy
  check_join: Boolean
}

extend type Mutation {
  lobby_create(input: LobbyInput_create!): ID!

  lobby_join(id_lobby: ID!): Boolean

  lobby_leave(id_lobby: ID): Boolean
 
  lobby_request_create(id_lobby: ID!): Boolean

  lobby_request_confirm(id_lobby: ID!): Boolean

  lobby_request_deny(id_lobby: ID!): Boolean

  lobby_request_manage_accept(id_user: ID!, id_lobby: ID!): Boolean

  lobby_request_manage_deny(id_user: ID!, id_lobby: ID!): Boolean

  lobby_kick(id_user: ID!, id_lobby: ID!, timestamp: String): Boolean
}
`

export const resolvers = {
  Mutation: {
    lobby_create: async (obj, { input }, ctx, info) => {
      if (!ctx.viewer)
        return null
      input.id_viewer = ctx.viewer.id
      return await ctx.db.one("SELECT * FROM lobby_create(${id_viewer}, ${id_game}, ${id_platform}, ${id_cross}, ${max_size}, ${check_join}, ${privacy})", input)
    },
    lobby_join: async (obj, { id_lobby }, ctx, info) => {
      if (!ctx.viewer)
        return null
      let input = {
        id_viewer: ctx.viewer.id,
        id_lobby: id_lobby
      }
      return await ctx.db.one("SELECT * FROM lobby_join(${id_viewer}, ${id_lobby})", input)
    },
    lobby_leave: async (obj, { id_lobby }, ctx, info) => {
      if (!ctx.viewer)
        return null
      let input = {
        id_viewer: ctx.viewer.id,
        id_lobby: id_lobby
      }
      return await ctx.db.one("SELECT * FROM lobby_leave(${id_viewer}, ${id_lobby})", input)
    },
    //LOBBY_REQUEST
    lobby_request_create: async (obj, { id_lobby }, ctx, info) => {
      if (!ctx.viewer)
        return null
      let input = {
        id_viewer: ctx.viewer.id,
        id_lobby: id_lobby
      }
      return await ctx.db.one("SELECT * FROM lobby_request_create(${id_viewer}, ${id_lobby})", input)
    },
    lobby_request_confirm: async (obj, { id_lobby }, ctx, info) => {
      if (!ctx.viewer)
        return null
      let input = {
        id_viewer: ctx.viewer.id,
        id_lobby: id_lobby
      }
      return await ctx.db.one("SELECT * FROM lobby_request_confirm(${id_viewer}, ${id_lobby})", input)
    },
    lobby_request_manage_accept: async (obj, { id_lobby, id_user }, ctx, info) => {
      if (!ctx.viewer)
        return null
      let input = {
        id_viewer: ctx.viewer.id,
        id_lobby: id_lobby,
        id_user: id_user
      }
      return await ctx.db.one("SELECT * FROM lobby_request_manage_accept(${id_viewer}, ${id_user}, ${id_lobby})", input)
    },
    lobby_request_manage_deny: async (obj, { id_user, id_lobby }, ctx, info) => {
      if (!ctx.viewer)
        return null
      let input = {
        id_viewer: ctx.viewer.id,
        id_lobby: id_lobby,
        id_user: id_user
      }
      return await ctx.db.one("SELECT * FROM lobby_request_manage_deny(${id_viewer}, ${id_user}, ${id_lobby})", input)
    },
    //PERMISSIONS
    lobby_kick: async (obj, { id_user, id_lobby, timestamp }, ctx, info) => {
      if (!ctx.viewer)
        return null
      let input = {
        id_viewer: ctx.viewer.id,
        id_user: id_user,
        id_lobby: id_lobby,
        timestamp: timestamp,
      }
      return await ctx.db.one("SELECT * FROM lobby_kick(${id_viewer}, ${id_user}, ${id_lobby}, ${timestamp})", input)
    }
  }
}