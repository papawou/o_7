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
  populate: Boolean!
  clear: Boolean!
}
`

export const resolvers = {
  Query: {
    test: async (root, args, context, info) => {
      /*await reset(root, args, context, info)
      await context.db.any(context.sql.test.wip)
      //await context.db.any(context.sql.test.test)
      await context.db.any(context.sql.test.populate)
      //EXEC
      
      await context.db.one("SELECT * FROM lobby_kickmember(${id_lobby}, ${id_user})", args.input)
      */
      try {
        context.db.tx(async t => {
          await t.one('SELECT pg_advisory_xact_lock(1)')
          await t.one('SELECT pg_sleep(20)')
        })
      }
      catch (err) {
        console.log(err)
      }
      return true
    }
  },
  Mutation: {
    reset: async (root, args, context, info) => {
      await reset(root, args, context, info)
      return true
    },
    clear: async (root, args, context, info) => {
      await clear(root, args, context, info)
      return true
    },
    populate: async (root, args, context, info) => {
      await populate(root, args, context, info)
      return true
    }
  }
}

const reset = async (root, args, context, info) => {
  await clear(root, args, context, info)
  await populate(root, args, context, info)
}

const clear = async (root, args, context, info) => {
  await context.db.any(context.sql.utils.reset)
  await context.db.any(context.sql.user.table)
  await context.db.any(context.sql.user.func)

  await context.db.any(context.sql.game.table)

  await context.db.any(context.sql.lobby.table)
  await context.db.any(context.sql.lobby.func)
}

const populate = async (root, args, context, info) => {
  await context.db.any(context.sql.utils.populate)
}