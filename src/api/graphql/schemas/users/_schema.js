import * as _ from 'lodash'

import * as User from './User'
import * as Viewer from './Viewer'
import * as Friendship from './Friendship'

export const schema = [
    User.schema,
    Viewer.schema,
    Friendship.schema
]

export const resolvers = {}
_.merge(resolvers, User.resolvers)
_.merge(resolvers, Viewer.resolvers)
_.merge(resolvers, Friendship.resolvers)
