import pgp from 'pg-promise'

export const schema = `
enum TeamLogRequestStatus {
    CANCELED
    ACCEPTED
    DENIED
}
type TeamLogRequest {
    team: Team!
    user: User!

    data_request: String

    status: TeamLogRequestStatus
    created_at: String!
    resolved_at: String!
    resolved_by: User
}

extend type Viewer {
    teamLogRequests(id_team: ID, status: [TeamLogRequestStatus!]): [TeamLogRequest]!
}
extend type User {
    teamLogRequests(id_team: ID!, status: [TeamLogRequestStatus!]): [TeamLogRequest]!
}
extend type Team {
    logRequests(id_user: ID, status: [TeamLogRequestStatus!]): [TeamLogRequest]!
}
`

const toArrayLogTeamRequestStatus = list_status => ({
    rawType: true,
    toPostgres: () => list_status && list_status.length > 0 ? pgp.as.format('ARRAY[$1:csv]::log_teamrequest_status[]', list_status) : "ARRAY[]::log_teamrequest_status[]"
})

export const resolvers = {
    TeamLogRequest: {
        team: async (root, args, context, info) => {
            return await context.db.one('SELECT * FROM teams WHERE id=$1', root.id_team)
        },
        user: async (root, args, context, info) => {
            return await context.db.one('SELECT * FROM users WHERE id=$1', root.id_user)
        }
    },
    Viewer: {
        teamLogRequests: async (root, { id_team, status }, context, info) => {
            let res
            let args_sql = {
                id_team: id_team,
                status: toArrayLogTeamRequestStatus(status),
                id_viewer: context.req.session._id
            }
            try {
                res = await context.db.any('SELECT * FROM getviewerlogteamrequests($<id_team>, $<status>, $<id_viewer>)', args_sql)
            }
            catch (err) {
                console.log(err)
                throw (err)
            }
            return res
        }
    },
    User: {
        teamLogRequests: async (root, { id_team, status }, context, info) => {
            let res
            let args_sql = {
                id_team: id_team,
                id_user: root.id,
                status: toArrayLogTeamRequestStatus(status),
                id_viewer: context.req.session._id
            }
            try {
                res = await context.db.any("SELECT * FROM getlogteamrequests($<id_team>,$<id_user>, $<status>, $<id_viewer>)", args_sql)
            }
            catch (err) {
                console.log(err)
                throw (err)
            }
            return res
        }
    },
    Team: {
        logRequests: async (root, { id_user, status }, context, info) => {
            let res
            let args_sql = {
                id_team: root.id,
                id_user: id_user,
                status: toArrayLogTeamRequestStatus(status),
                id_viewer: context.req.session._id
            }
            try {
                res = await context.db.any("SELECT * FROM getlogteamrequests($<id_team>, $<id_user>, $<status>, $<id_viewer>)", args_sql)
            }
            catch (err) {
                console.log(err)
                throw (err)
            }
            return res
        }
    }
}