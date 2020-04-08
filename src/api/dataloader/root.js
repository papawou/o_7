import DataLoader from 'dataloader'

import { User } from '../graphql/schemas/users/User.js'
import { Lobby } from '../graphql/schemas/lobbys/Lobby.js'
import { LobbyMembersConnection, LobbyMember } from '../graphql/schemas/lobbys/LobbyMember'
import { GamePlatform, GameCross } from '../graphql/schemas/game_platform/GamePlatform.js'
import { Platform, PlatformGamesConnection } from '../graphql/schemas/game_platform/Platform.js'
import { Game, GamePlatformsConnection } from '../graphql/schemas/game_platform/Game.js'
import { AuthLobby } from '../graphql/schemas/auth/lobby.js'

export class Loaders {
    constructor(ctx) {
        this.user = new DataLoader(ids => User.load(ids, ctx))

        this.lobby = new DataLoader(ids => Lobby.load(ids, ctx))
        this.lobbymembers = new DataLoader(ids => LobbyMembersConnection.load(ids, ctx))
        this.lobbymemberByUser = new DataLoader(ids => LobbyMember.loadByUser(ids, ctx))

        this.game = new DataLoader(ids => Game.load(ids, ctx))
        this.gameplatforms = new DataLoader(ids => GamePlatformsConnection.load(ids, ctx))
        this.platform = new DataLoader(ids => Platform.load(ids, ctx))
        this.platformgames = new DataLoader(ids => PlatformGamesConnection.load(ids, ctx))

        this.gameplatform = new DataLoader(ids => GamePlatform.load(ids, ctx))
        this.gamecross = new DataLoader(ids => GameCross.load(ids, ctx))

        //AUTH
        this.authlobby = new DataLoader(ids => AuthLobby.load(ids, ctx))
    }
}