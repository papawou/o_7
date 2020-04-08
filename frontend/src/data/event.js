const event = {
    event_modes: [
        "default",
        "match",
        "tournament",
        "contest"
    ],

    privacies: {
        default: [
            "none",
            "invitation"
        ],
        groups: [
            "members"
        ],
        teams: [
            "members"
            //...team.roles
        ],
        sections: [
            "members"
            //...section.roles
        ],
        users: [
            "followers",
            "friends"
        ]
    }
}

export default event