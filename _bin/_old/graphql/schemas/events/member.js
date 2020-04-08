export const schema = `
type EventMember {
  event: Event!
  user: User!
  data_member: String
}

extend type User {
  memberEvents: [EventMember]!
}
extend type Event {
  members: [EventMember]!
}
`

export const resolvers = {
  EventMember: {
    event: async (root, args, context, info) => {
      return await context.db.one('SELECT * FROM events WHERE id=$1', root.id_event)
    },
    user: async (root, args, context, info) => {
      return await context.db.one('SELECT * FROM users WHERE id=$1', root.id_user)
    }
  },
  User: {
    memberEvents: async (root, args, context, info) => {
      return await context.db.any('SELECT * FROM eventmembers WHERE id_user=$1', root.id)
    }
  },
  Event: {
    members: async (root, args, context, info) => {
      return await context.db.any('SELECT * FROM eventmembers WHERE id_event=$1', root.id)
    }
  }
}