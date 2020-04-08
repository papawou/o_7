import * as _ from 'lodash'

import * as User from './User'
import * as Viewer from './Viewer'

export const schema = [
    User.schema,
    Viewer.schema
]

export const resolvers = {}
_.merge(resolvers, User.resolvers)
_.merge(resolvers, Viewer.resolvers)
