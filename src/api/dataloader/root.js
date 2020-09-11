import DataLoader from 'dataloader'

import { User } from '../graphql/schemas/users/User.js'
import { Friendship, FriendshipConnection } from '../graphql/schemas/users/Friendship.js'
import { Follow, FollowerConnection, FollowingConnection } from '../graphql/schemas/users/Follow.js'

const initLoaders = (ctx) => {
    return {
        user: new DataLoader(ids => User.load(ctx, ids)),
        //friendship
        friendship: new DataLoader(ids => Friendship.load(ctx, ids)),
        friendships: new DataLoader(ids => FriendshipConnection.load(ctx, ids)),
        //follows
        follow: new DataLoader(ids => Follow.load(ctx,ids)),
        followers: new DataLoader(ids => FollowerConnection.load(ctx, ids)),
        followings: new DataLoader(ids => FollowingConnection.load(ctx, ids))
    }
}

export default initLoaders
/*
export default class Loaders {
    constructor(ctx) {
        this.user = new DataLoader(ids => User.load(ctx, ids))
        //friendship
        this.friendship = new DataLoader(ids => Friendship.load(ctx, ids))
        this.friendships = new DataLoader(ids => FriendshipConnection.load(ctx, ids))
    }
}
*/