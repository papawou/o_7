import * as _ from 'lodash'

import * as Lobby from './lobby'

export const schema = [
    Lobby.schema
]

export const resolvers = {}
_.merge(resolvers, Lobby.resolvers)
