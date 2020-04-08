export const schema = `
type EventRequest {
    event: Event!
    user: User!
    data_request: String
}

extend type User {
    requestEvents: [EventRequest]!
}
extend type Event {
    requests: [EventRequest]!
}
`

export const resolvers = {
    EventRequest: {
        event:async (root, args, context, info) => {
            return await context.db.one('SELECT * FROM events WHERE id=$1', root.id_event)
        },
        user: async(root, args, context, info) => {
            return await context.db.one('SELECT * FROM users WHERE id=$1', root.id_user)
        }
    },
    User: {
        requestEvents:async (root, args, context, info) => {
            return await context.db.any('SELECT * FROM eventrequests WHERE id_user=$1', root.id)
        }
    },
    Event: {
        requests:async (root, args, context, info) => {
            return await context.db.any('SELECT * FROM eventrequests WHERE id_event=$1', root.id)
        }
    }
}