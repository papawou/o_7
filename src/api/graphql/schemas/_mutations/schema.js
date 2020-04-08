import * as _ from 'lodash'

import * as lobby from './lobby'

export const schema = [
    lobby.schema
]

export const resolvers = {}
_.merge(resolvers, lobby.resolvers)