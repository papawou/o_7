export const schema = `
union EventOwner = User | Team
type Event {
  id: ID!
  name: String!
  owner: EventOwner!
  
  game: Game!
  platform: Platform!

  data_event: String
}

extend type Query {
  event(id: ID!): Event
}

extend type User {
  ownerEvents: [Event]!
}
extend type Team {
  ownerEvents: [Event]!
}
`

export const resolvers = {
  EventOwner: {
    __resolveType(root, context, info) {
      return root.type
    }
  },
  Event: {
    owner: async (root, args, context, info) => {
      let owner = {}
      if (root.id_user != null) {
        owner = await context.db.one('SELECT * FROM users WHERE id=$1', root.id_user)
        owner['type'] = 'User'
      }
      else if (root.id_team != null) {
        owner = await context.db.one('SELECT * FROM teams WHERE id=$1', root.id_team)
        owner['type'] = 'Team'
      }

      return owner
    }
  },
  Query: {
    event: async (root, { id }, context, info) => {
      return await context.db.one('SELECT * FROM events WHERE id=$1', id)
    }
  },
  User: {
    ownerEvents: async (root, args, context, info) => {
      return await context.db.any('SELECT * FROM events WHERE id_user=$1', root.id)
    }
  },
  Team: {
    ownerEvents: async (root, args, context, info) => {
      return await context.db.any('SELECT * FROM events WHERE id_team=$1', root.id)
    }
  }
}