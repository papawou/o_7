import pgp from 'pg-promise'

export const schema = `
enum TeamLogMemberReason {
    LEAVED
    KICKED
}
type TeamLogMember {
    team: Team!
    user: User!

    data_member: String

    reason: TeamLogMemberReason
    joined_at: String!
    leaved_at: String!
}

extend type Viewer {
    teamLogMembers(id_team: ID, reasons: [TeamLogMemberReason!]): [TeamLogMember]!
}
extend type User {
    teamLogMembers(id_team: ID, reasons: [TeamLogMemberReason!]): [TeamLogMember]!
}
extend type Team {
    logMembers(id_user: ID, reasons: [TeamLogMemberReason!]): [TeamLogMember]!
}
`

const toArrayLogTeamMemberReason = list_reason => ({
    rawType: true,
    toPostgres: () => list_reason && list_reason.length > 0 ? pgp.as.format('ARRAY[$1:csv]::log_teammember_reason[]', list_reason) : "ARRAY[]::log_teammember_reason[]"
})

export const resolvers = {
    TeamLogMember: {
        team: async (root, args, context, info) => {
            return await context.db.one('SELECT * FROM teams WHERE id=$1', root.id_team)
        },
        user: async (root, args, context, info) => {
            return await context.db.one('SELECT * FROM users WHERE id=$1', root.id_user)
        }
    },
    Viewer: {
        teamLogMembers: async (root, { id_team, reasons }, context, info) => {
            let res
            let args_sql = {
                id_team: id_team,
                reasons: toArrayLogTeamMemberReason(reasons),
                id_viewer: context.req.session._id
            }
            try {
                res = await context.db.any('SELECT * FROM getviewerlogteammembers($<id_team>,$<id_viewer>, $<reasons>)', args_sql)
            }
            catch (err) {
                console.log(err)
                throw (err)
            }
            return res
        }
    },
    User: {
        teamLogMembers: async (root, { id_team, reasons }, context, info) => {
            let res
            let args_sql = {
                id_team: id_team,
                id_user: root.id,
                reasons: toArrayLogTeamMemberReason(reasons),
                id_viewer: context.req.session._id
            }
            try {
                res = await context.db.any("SELECT * FROM getlogteammembers($<id_team>,$<id_user>, $<reasons>)", args_sql)
            }
            catch (err) {
                console.log(err)
                throw (err)
            }
            return res
        }
    },
    Team: {
        logMembers: async (root, { id_user, reasons }, context, info) => {
            let res
            let args_sql = {
                id_team: root.id,
                id_user: id_user,
                reasons: toArrayLogTeamMemberReason(reasons),
                id_viewer: context.req.session._id
            }
            try {
                res = await context.db.any("SELECT * FROM getlogteammembers($<id_team>, $<id_user>, $<reasons>)", args_sql)
            }
            catch (err) {
                console.log(err)
                throw (err)
            }
            return res
        }
    }
}