import * as _ from 'lodash'

import * as Lobby from './Lobby'
import * as LobbyMember from './LobbyMember'

export const schema = [
    Lobby.schema,
    LobbyMember.schema
]

export const resolvers = {}
_.merge(resolvers, Lobby.resolvers)
_.merge(resolvers, LobbyMember.resolvers)