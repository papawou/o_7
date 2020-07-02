export const schema = `
enum frienshiprequest_status {
  WAITING_TARGET
  DECLINED
}
type FriendshipRequest {
  id: ID!
  creator: User!
  target: User!

  status
}

extend type Query {
  user(id: ID!): User
}
`