export const schema = `
type User {
  id: ID!
  name: String!
  data: String
}

extend type Query {
  user(id: ID!): User
}
`

export const resolvers = {
  Query: {
    user: async (root, { id }, context, info) => {
      return await context.db.one('SELECT * FROM users WHERE id=$1', id)
    }
  },
  Mutation: {
  }
}