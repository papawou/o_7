export const schema = `
type Viewer {
  id: ID!
  name: String!
  data: String
}

extend type Query {
  viewer: Viewer
}
`

export const resolvers = {
  Viewer: {
  },
  Query: {
    viewer: async (root, {id}, context, info ) => {
      return await context.db.one('SELECT * FROM users WHERE id=$1', context.req.session._id)
    }
  }
}