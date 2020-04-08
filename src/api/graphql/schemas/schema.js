import * as _ from 'lodash'

import * as Root from './root'
import * as users from './users/_schema'
import * as lobbys from './lobbys/_schema'
import * as game_platform from './game_platform/_schema'
import * as auth from './auth/_schema'
import * as mutation from './_mutations/schema'

export const schemas = [
    Root.schema,
    ...users.schema,
    ...lobbys.schema,
    ...game_platform.schema,
    ...mutation.schema
]

export const resolvers = {}

_.merge(resolvers, Root.resolvers)
_.merge(resolvers, users.resolvers)
_.merge(resolvers, lobbys.resolvers)
_.merge(resolvers, game_platform.resolvers)
_.merge(resolvers, mutation.resolvers)