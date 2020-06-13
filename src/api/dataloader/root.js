import DataLoader from 'dataloader'

import { User } from '../graphql/schemas/users/User.js'
import { Friendship, FriendshipConnection } from '../graphql/schemas/users/Friendship.js'

/*
const initLoaders = (ctx) => {
    return {
        user: new DataLoader(ids => User.load(ctx, ids)),
        //friendship
        friendship: new DataLoader(ids => Friendship.load(ctx, ids)),
        friendships: new DataLoader(ids => FriendshipConnection.load(ctx, ids)),
    }
}

export default initLoaders
*/
export default class Loaders {
    constructor(ctx) {
        this.user = new DataLoader(ids => User.load(ctx, ids))
        //friendship
        this.friendship = new DataLoader(ids => Friendship.load(ctx, ids))
        this.friendships = new DataLoader(ids => FriendshipConnection.load(ctx, ids))
    }
}