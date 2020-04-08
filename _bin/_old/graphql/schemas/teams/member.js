export const schema = `
type TeamMember {
    team: Team!
    user: User!
    data_member: String,

    joined_at: String!
}

extend type Team {
    members: [TeamMember]!
    member(id_user: ID!): TeamMember
}
extend type Viewer {
    memberTeams: [TeamMember]!
    memberTeam(id_team: ID!): TeamMember
}
extend type User {
    memberTeams: [TeamMember]!
    memberTeam(id_team: ID!): TeamMember
}
`

export const resolvers = {
    TeamMember: {
        team: async (root, args, context, info) => {
            return await context.db.one('SELECT * FROM teams WHERE id=$1', root.id_team)
        },
        user: async (root, args, context, info) => {
            return await context.db.one('SELECT * FROM users WHERE id=$1', root.id_user)
        }
    },
    Team: {
        members: async (root, args, context, info) => {
            return await context.db.any('SELECT * FROM teammembers WHERE id_team=$1', root.id)
        },
        member: async (root, { id_user }, context, info) => {
            let args_sql = {
                id_team: root.id,
                id_user: id_user
            }
            return await context.db.one("SELECT * FROM teammembers WHERE id_team=$<id_team> AND id_user=$<id_user>", args_sql)
        }
    },
    Viewer: {
        memberTeams: async (root, args, context, info) => {
            return await context.db.any("SELECT * FROM teammembers WHERE id_user=$1", context.req.session._id)
        },
        memberTeam: async (root, { id_team }, context, info) => {
            let args_sql = {
                id_viewer: context.req.session._id,
                id_team: id_team
            }
            return await context.db.one("SELECT * FROM teammembers WHERE id_user=$<id_viewer> AND id_team=$<id_team>", args_sql)
        }
    },
    User: {
        memberTeams: async (root, args, context, info) => {
            return await context.db.any('SELECT * FROM teammembers WHERE id_user=$1', root.id)
        },
        memberTeam: async (root, { id_team }, context, info) => {
            let args_sql = {
                id_user: root.id,
                id_team: id_team
            }
            return await context.db.one("SELECT * FROM teammembers WHERE id_user=$<id_user> AND id_team=$<id_team>", args_sql)
        }
    }
}