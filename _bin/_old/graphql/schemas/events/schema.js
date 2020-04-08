import * as _ from 'lodash'

import * as Member from './member'
import * as Event from './event'
import * as Request from './request'

export const schema = [
    Event.schema,
    Member.schema,
    Request.schema
]

let root_resolvers = {}
_.merge(root_resolvers, Event.resolvers)
_.merge(root_resolvers, Member.resolvers)
_.merge(root_resolvers, Request.resolvers)

export const resolvers = root_resolvers