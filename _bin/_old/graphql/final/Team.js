const teamLoader = new DataLoader(async ids => {
    let teams = await db.any("SELECT * FROM teams WHERE id=ANY($1::int[])", ids)
    return teams
})
class Team {
    constructor(team) {
        this.id = team.id
        this.name = team.name
    }
    static async gen(viewer, id) {
        let team = db.one("SELECT * WHERE id_team=${id}", { id: id })
        return team ? new Team(team) : null
    }

    async members() {
        let ids_member = await db.any("SELECT * FROM teammembers WHERE id_team=$1", this.id)
        let members = ids_member.map(id_member => User.gen(id_member))
        return members
    }
}

const userLoader = new DataLoader(async ids => {
    let users = await db.any("SELECT * FROM users WHERE id=ANY($1::int[])", ids)
    return users
})
class User {
    constructor(user) {
        this.id = user.id
        this.name = user.name
    }
    static async gen(viewer, id) {
        let user = await userLoader.load(id)
        return user ? new User(user) : null
    }

    async teams() {
        let ids_team = await db.any("SELECT * FROM teammembers WHERE id_user=$1", this.id)
        let teams = ids_team.map(id_team => Team.gen(id_team))
        return teams
    }
}

let schema = buildSchema(`
  type Team {
      id: ID!
      name: String!
      owner: User!
      members: [User]!
  }

  type User {
      id: ID!
      name: String!
      teams: [Team]!
  }

  type Query {
    user(id: ID!): User
    team(id: ID!): Team
  }
`)

let resolvers = {
    user: (obj, { id }, { viewer }, info) => User.gen(viewer, id),
    team: (obj, { id }, { viewer }, info) => Team.gen(viewer, id)
}