import React, { Component } from 'react'
import * as api from '../../../utils/api'
import withAuth from '../../../contexts/Auth'
import { Link } from 'react-router-dom'

import * as css from './css/Team.js'

const Member = (props) => <li><Link to={`/user/${props.member._id}`}>{props.member.name} / {props.member.role}</Link></li>

const Members = (props) => <ul>{props.members.map(member => <Member key={member} member={member} />)}</ul>

const UserPanel = ({ team_user }) => <div>
    you are {team_user.role}
    {team_user.role == 'foundator' ? <button>EDIT TEAM</button> : null}
</div>

const Section = ({ section }) => <div>
    <Link to={`/section/${section._id}`}>{section.name}</Link>
</div>

class Team extends Component {
    constructor(props) {
        super(props)
        this.state = {
            _id: this.props.match.params.id_team,
            sections: [],
            members: [],
            name: "",
            prefix: "",
            langs: [],
            social: null,
            selected_section: null,
            //?section=id_section
            section: null
        }
    }

    componentDidMount() {
        api.afetch('team/get', { id: this.state._id })
            .then(team => {
                console.log(team)
                this.setState(team)
            })
            .catch(err => this.handleCustomError(err, 'team/get'))
    }

    handleChange = (e) => {
        let target = e.target
        if (target.type != 'checkbox')
            e.preventDefault()
        let name = target.name
        let value = target.type === 'checkbox' ? target.checked : target.type === 'select-multiple' ? Array.from(target.selectedOptions, option => option.value) : target.value

        this.setState({ [name]: value })
    }

    handleCustomError = (err, origin = false) => {
        switch (err.err) {
            default: {
                err.err ? console.log('team - api.err NOT HANDLE:' + err.err + ' / ' + origin) : console.log('team - ERROR NOT FORMATED / ' + origin)
                console.log(err)
                break;
            }
        }
    }

    render() {
        const team_user = this.props.userContext.teams.find(team => team._id == this.state._id)
        return <css.Container>
            {this.state.name}<br />
            <br />
            {
                team_user &&
                <UserPanel team_user={team_user} />
            }
            members:
            <Members members={this.state.members} />
            <select onChange={this.handleChange} name="selected_section">
                <option value="">-- select a section --</option>
                {this.state.sections.map(section =>
                    <option key={section._id} value={section._id}>{section.name}</option>
                )}
            </select>
            {
                this.state.selected_section &&
                <Section
                    section={this.state.sections.find(section => section._id == this.state.selected_section)}
                />
            }
        </css.Container>
    }
}

export default withAuth(Team)