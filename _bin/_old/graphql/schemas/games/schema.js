import * as _ from 'lodash'

import * as Game from './game'
import * as Platform from './platform'

export const schema = [
    Game.schema,
    Platform.schema
]

let root_resolvers = {}
_.merge(root_resolvers, Game.resolvers)
_.merge(root_resolvers, Platform.resolvers)

export const resolvers = root_resolvers