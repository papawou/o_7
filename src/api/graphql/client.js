import graphqlHTTP from 'express-graphql'
import { makeExecutableSchema as buildSchema } from 'graphql-tools'
import * as root_schema from './schemas/_schema'

import { Context } from './context'

const schema = buildSchema({
    typeDefs: root_schema.schemas,
    resolvers: root_schema.resolvers
})

const graphHTTP = graphqlHTTP(
    async (request, response, graphQLParams) => ({
        schema: schema,
        context: Context.gen(request, response),
        graphiql: true
    })
)

export default graphHTTP