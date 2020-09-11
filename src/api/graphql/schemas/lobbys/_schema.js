import * as _ from 'lodash'

import * as Lobby from './Lobby'
import * as LobbyUser from './LobbyUser'
import * as LobbyBan from './LobbyBan'
import * as LobbyMember from './LobbyMember'
import * as LobbyRequest from './LObbyRequest'

export const schema = [
    Lobby.schema,
    /*LobbyUser.schema,
    LobbyBan.schema,
    LobbyMember.schema,
    LobbyRequest.schema*/
]

export const resolvers = {}
_.merge(resolvers, Lobby.resolvers)
/*_.merge(resolvers, LobbyUser.resolvers)
_.merge(resolvers, LobbyBan.resolvers)
_.merge(resolvers, LobbyMember.resolvers)
_.merge(resolvers, LobbyRequest.resolvers)*/