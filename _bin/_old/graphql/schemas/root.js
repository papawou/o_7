export const schema = `
schema {
  query: Query
  mutation: Mutation
}

type Query {
  test: Boolean
}

type Mutation {
  reset: Boolean!
  test: Boolean!
}
`

export const resolvers = {
  Query: {
    test: async (root, args, context, info) => {
      let res
      try {
        res = await context.db.any(context.sql.test)
      }
      catch (err) {
        console.log(err)
        throw (err)
      }
      return true
    }
  },
  Mutation: {
    reset: async (root, args, context, info) => {
      try {
        return await context.db.task('resetTask', async (task) => {
          await context.db.any(context.sql.init)
          await context.db.any(context.sql.populate)
          await context.db.any(context.sql.team.team)
          await context.db.any(context.sql.team.request)
          await context.db.any(context.sql.team.member)
          return true
        })
      }
      catch (error) {
        console.log(error)
        throw (error)
      }
    },
    test: async (root, args, context, info) => {
      let res
      try {
        res = await context.db.any(context.sql.test)
      }
      catch (err) {
        console.log(err)
        throw (err)
      }
      return true
    }
  }
}