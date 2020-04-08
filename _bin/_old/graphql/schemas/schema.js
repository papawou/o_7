import * as _ from 'lodash'

import * as Root from './root'
import * as Event from './events/schema'
import * as Team from './teams/schema'
import * as User from './users/schema'
import * as Game from './games/schema'

export const schemas = [
    Root.schema,
    ...Event.schema,
    ...Team.schema,
    ...User.schema,
    ...Game.schema
]
let root_resolvers = {}
_.merge(root_resolvers, Root.resolvers)
_.merge(root_resolvers, Event.resolvers)
_.merge(root_resolvers, Team.resolvers)
_.merge(root_resolvers, User.resolvers)
_.merge(root_resolvers, Game.resolvers)

export const resolvers = root_resolvers