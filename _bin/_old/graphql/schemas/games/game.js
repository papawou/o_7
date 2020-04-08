export const schema = `
type Game {
  id: ID!
  name: String!
  platforms: [Platform]!
}

extend type Query {
  game(id: ID!): Game
}
`

export const resolvers = {
  Query: {
    game: async (root, args, context, info) => {
      return await context.db.one('SELECT * FROM games WHERE id=$1', args.id)
    }
  },
  Game: {
    platforms: async (root, args, context, info) => {
      return await context.db.any('SELECT platforms.* FROM gameplatform JOIN platforms ON platforms.id=gameplatform.id_platform WHERE id_game=$1', root.id)
    }
  }
}