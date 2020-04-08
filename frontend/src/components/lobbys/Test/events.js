export const privacy = (value, event) => {
    let query = null
    let input = "this"
    switch (value) {
        case "invitation":
            query = { $in: [event._id, "$$profile"] }
            break;
        case "followers":
            input = "$followed"
            query = { $in: [event.owner._id, "$$profile"] }
            break;
        case "members":
            input = "$event"
            query = { $in: ["member", "$$profile.roles"] }
            break;
        case "friends":
            input = "$friends"
            query = { $in: [event.owner._id, "$$profile"] }
            break;
        case "none":
            break;
        default:
            throw ({ id_rule: "privacy", msg: "unknow value" })
    }
    return { input: input, query: query }
}

export const generateQueries = (queries, event) => {
    return Object.keys(queries).map(id_input => {
        return groups(id_input, queries[id_input], event)
    })
}

const groups = (id_input, queries, event) => {
    let group = {}
    switch (id_input) {
        case "$followed":
            group = {
                $let: {
                    vars: {
                        profile: {
                            $arrayElemAt: [
                                {
                                    $filter: {
                                        input: "$followed",
                                        as: "doc",
                                        cond: { $eq: ["$$doc._id", event.owner._id] }
                                    }
                                }, 0]
                        }
                    },
                    in: queries
                }
            }
            break;
        default:
            console.log("default")
    }
    return group
}