import * as _ from 'lodash'

import * as Root from './root'
import * as users from './users/_schema'
import * as mutation from './_mutations/schema'

export const schemas = [
    Root.schema,
    ...users.schema,
    ...mutation.schema
]

export const resolvers = {}

_.merge(resolvers, Root.resolvers)
_.merge(resolvers, users.resolvers)
_.merge(resolvers, mutation.resolvers)