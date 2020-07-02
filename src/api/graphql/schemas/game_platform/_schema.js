import * as _ from 'lodash'

import * as Game from './Game'
import * as Platform from './Platform'
import * as GamePlatform from './GamePlatform'
import * as GameCross from './GameCross'

export const schema = [
    Game.schema,
    Platform.schema,
    GamePlatform.schema,
    GameCross.schema
]

export const resolvers = {}
_.merge(resolvers, Game.resolvers)
_.merge(resolvers, Platform.resolvers)
_.merge(resolvers, GamePlatform.resolvers)
_.merge(resolvers, GameCross.resolvers)