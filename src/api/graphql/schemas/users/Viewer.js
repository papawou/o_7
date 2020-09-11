import { User } from "./User"

export const schema = `
type Viewer implements UserInterface {
  id: ID!
  name: String!
  created_at: String!

  friends: FriendshipConnection!

  followers: FollowerConnection!
  followings: FollowingConnection!
}

extend type Query {
  viewer: Viewer
}
`

export const resolvers = {
  Query: {
    viewer: async (root, args, context, info) => context.viewer
  }
}

export class Viewer extends User {
}