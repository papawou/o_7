import * as _ from 'lodash'

import * as Lobby from './Lobby'
import * as LobbyMembers from './LobbyMembers'

export const schema = [
    Lobby.schema,
    LobbyMembers.schema
]

export const resolvers = {}
_.merge(resolvers, Lobby.resolvers)
_.merge(resolvers, LobbyMembers.resolvers)