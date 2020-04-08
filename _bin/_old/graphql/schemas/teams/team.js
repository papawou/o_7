export const schema = `
type Team {
  id: ID!
  name: String!
  owner: User!
  data_team: String,

  created_at: String!
}

extend type User {
  ownerTeams: [Team]!
}

extend type Query {
  team(id: ID!): Team
}
extend type Mutation {
  createTeam(name: String!): ID!
  joinTeam(id: ID!): Boolean!
  leaveTeam(id: ID!): Boolean!
  kickteamMember(id_team: ID!, id_user: ID!): Boolean!
}
`

export const resolvers = {
    Team: {
        owner: async (root, args, context, info) => {
            return await context.db.one('SELECT * FROM users WHERE id=$1', root.id_user)
        }
    },
    User: {
        ownerTeams: async (root, args, context, info) => {
            return await context.db.any('SELECT * FROM teams WHERE id=$1', root.id)
        }
    },
    Query: {
        team: async (root, { id }, context, info) => {
            return await context.db.one('SELECT * FROM teams WHERE id=$1', id)
        }
    },
    Mutation: {
        createTeam: async (root, { name }, context, info) => {
            let res
            let args_sql = {
                name: name,
                id_viewer: context.req.session._id
            }
            try {
                res = await context.db.one("SELECT * FROM createteam($<name>, $<id_viewer>)", args_sql)
            }
            catch (err) {
                console.log(err)
                switch (err.constraint) {
                    case 'teams_lower_idx':
                        throw ('team_name_taken')
                        break
                    default:
                        throw (err)
                }
            }
            return res.id
        },
        joinTeam: async (root, { id }, context, info) => {
            let res
            let args_sql = {
                id_team: id,
                id_viewer: context.req.session._id
            }
            try {
                res = await context.db.one("SELECT * FROM jointeam($<id_team>, $<id_viewer>)", args_sql)
            } catch (err) {
                console.log(err)
                switch (err.constraint) {
                    case 'teamrequests_id_team_fkey':
                        throw ('team not found')
                        break
                    case 'teamrequests_pkey':
                        throw ('request already exist')
                        break
                    default:
                        throw (err)
                }
            }

            return res.success
        },
        leaveTeam: async (root, { id }, context, info) => {
            let res
            let args_sql = {
                id_team: id,
                id_viewer: context.req.session._id
            }
            try {
                res = await context.db.one("SELECT * FROM leaveteam($<id_team>,$<id_viewer>)", args_sql)
            }
            catch (err) {
                console.log(err)
                throw (err)
            }

            return res.success
        },
        kickteamMember: async (root, { id_user, id_team }, context, info) => {
            let res
            let args_sql = {
                id_team: id_team,
                id_user: id_user,
                id_viewer: context.req.session._id
            }
            try {
                res = await context.db.one("SELECT * FROM kickteammember($<id_team>, $<id_user>, $<id_viewer>)", args_sql)
            }
            catch (err) {
                console.log(err)
                throw (err)
            }
            console.log(res)
            return res.success
        }
    }
}