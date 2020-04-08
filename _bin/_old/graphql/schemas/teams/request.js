export const schema = `
type TeamRequest {
    team: Team!
    user: User!

    data_request: String

    created_at: String!
}

extend type Viewer {
    teamRequests: [TeamRequest]!
    teamRequest(id_team: ID!): TeamRequest
}
extend type User {
    teamRequest(id_team: ID!): TeamRequest!
}
extend type Team {
    requests: [TeamRequest]!
    request(id_user: ID!): TeamRequest!
}

extend type Mutation{
    acceptTeamRequest(id_team: ID!, id_user: ID!): TeamMember!
    denyTeamRequest(id_team: ID!, id_user: ID!): Boolean!
    cancelTeamRequest(id_team: ID!): Boolean!
}
`

export const resolvers = {
    TeamRequest: {
        team: async (root, args, context, info) => {
            return await context.db.one('SELECT * FROM teams WHERE id=$1', root.id_team)
        },
        user: async (root, args, context, info) => {
            return await context.db.one('SELECT * FROM users WHERE id=$1', root.id_user)
        }
    },
    Viewer: {
        teamRequests: async (root, args, context, info) => {
            let res
            let args_sql = {
                id_viewer: context.req.session._id
            }
            try {
                res = await context.db.any("SELECT * FROM getviewerteamrequests($<id_viewer>)", args_sql)
            }
            catch (err) {
                console.log(err)
                throw (err)
            }
            return res
        },
        teamRequest: async (root, { id_team = null }, context, info) => {
            let request
            let args_sql = {
                id_team: id_team,
                id_viewer: context.req.session._id
            }
            try {
                request = await context.db.one("SELECT * FROM getviewerteamrequest($<id_team>, $<id_viewer>)", args_sql)
            }
            catch (err) {
                console.log(err)
                throw (err)
            }
            return request
        }
    },
    User: {
        teamRequest: async (root, { id_team = null }, context, info) => {
            let res
            let args_sql = {
                id_team: id_team,
                id_user: root.id,
                id_viewer: context.req.session._id
            }
            try {
                res = await context.db.one("SELECT * FROM getteamrequest($<id_team>, $<id_user>, $<id_viewer>)", args_sql)
            }
            catch (err) {
                console.log(err)
                throw (err)
            }
            return res
        }
    },
    Team: {
        request: async (root, { id_user }, context, info) => {
            let res
            let args_sql = {
                id_team: root.id,
                id_user: id_user,
                id_viewer: context.req.session._id
            }
            try {
                res = await context.db.one("SELECT * FROM getteamrequest($<id_team>, $<id_user>, $<id_viewer>)", args_sql)
            }
            catch (err) {
                console.log(err)
                throw (err)
            }
            return res
        },
        requests: async (root, args, context, info) => {
            let res
            let args_sql = {
                id_team: root.id,
                id_viewer: context.req.session._id
            }
            try {
                res = await context.db.any("SELECT * FROM getteamrequests($<id_team>, $<id_viewer>)", args_sql)
            }
            catch (err) {
                console.log(err)
                throw (err)
            }
            return res
        }
    },
    Query: {
    },
    Mutation: {
        acceptTeamRequest: async (root, { id_team, id_user }, context, info) => {
            let res
            let args_sql = {
                id_team: id_team,
                id_user: id_user,
                id_viewer: context.req.session._id
            }
            try {
                res = await context.db.one("SELECT * FROM acceptteamrequest($<id_team>, $<id_user>, $<id_viewer>)", args_sql)
            }
            catch (err) {
                console.log(err)
                throw (err)
            }
            return res
        },
        denyTeamRequest: async (root, { id_team, id_user }, context, info) => {
            let res
            let args_sql = {
                id_team: id_team,
                id_user: id_user,
                id_viewer: context.req.session._id
            }
            try {
                res = await context.db.one("SELECT * FROM denyteamrequest($<id_team>, $<id_user>, $<id_viewer>)", args_sql)
            }
            catch (err) {
                console.log(err)
                throw (err)
            }
            return res
        },
        cancelTeamRequest: async (root, { id_team }, context, info) => {
            let res
            let args_sql = {
                id_team: id_team,
                id_viewer: context.req.session._id
            }
            try {
                res = await context.db.one("SELECT * FROM cancelteamrequest($<id_team>, $<id_viewer>)", args_sql)
            }
            catch (err) {
                console.log(err)
                throw (err)
            }
            return true
        }
    }
}