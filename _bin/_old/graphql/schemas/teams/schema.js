import * as _ from 'lodash'

import * as Team from './team'
import * as Request from './request'
import * as Member from './member'
import * as LogRequest from './log_request'
import * as LogMember from './log_member'

export const schema = [
    Team.schema,
    Request.schema,
    Member.schema,
    LogRequest.schema,
    LogMember.schema
]

let root_resolvers = {}
_.merge(root_resolvers, Team.resolvers)
_.merge(root_resolvers, Request.resolvers)
_.merge(root_resolvers, Member.resolvers)
_.merge(root_resolvers, LogRequest.resolvers)
_.merge(root_resolvers, LogMember.resolvers)

export const resolvers = root_resolvers