export const schema = `
type Platform {
  id: ID!
  name: String!
  games: [Game]!
}

extend type Query {
  platform(id: ID!): Platform
}
`

export const resolvers = {
  Query: {
    platform: async (root, args, context, info) => {
      return await context.db.one('SELECT * FROM platforms WHERE id=$1', args.id)
    }
  },
  Platform: {
    games: async (root, args, context, info) => {
      return await context.db.any('SELECT games.* FROM gameplatform JOIN games ON games.id=gameplatform.id_game WHERE id_platform=$1', root.id)
    }
  }
}