import * as _ from 'lodash'

import * as User from './user'
import * as Viewer from './viewer'
export const schema = [
    User.schema,
    Viewer.schema
]

let root_resolvers = {}
_.merge(root_resolvers, User.resolvers, Viewer.resolvers)

export const resolvers = root_resolvers