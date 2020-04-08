import React, { Component } from 'react'
//utils
import { Link } from 'react-router-dom'
import withAuth from '../../contexts/Auth'
import * as api from '../../utils/api'
//css
import * as css from './css/User'

const User_topActions = (props) =>
    <css.User_topActions>
        {props.is_user ? <button>EDIT PROFILE</button> :
            <React.Fragment>
                <button>Add friend</button>
                <button>Send message</button>
            </React.Fragment>}
    </css.User_topActions>

const Games = (props) => <div><css.IconSvg src="/img/social/steam.svg" /></div>

const Social = (props) => <div><css.IconSvg src="/img/social/discord.svg" /></div>

const User_top = (props) =>
    <css.User>
        <css.Img src="/img/profile.jpg" />
        <css.User_Infos>
            <css.Names>{`${props.forename} "${props.username}" ${props.surname}`}</css.Names>
            <css.Desc>Utque aegrum corpus quassari etiam levibus solet offensis, ita animus eius angustus et tener, quicquid increpuisset, ad salutis suae dispendium existimans factum aut cogitatum, insontium caedibus fecit victoriam luctuosam.</css.Desc>
            <Games />
            <Social />
        </css.User_Infos>
        <User_topActions is_user={props.is_user} />
    </css.User >

const Team = ({ team }) => <li><Link to={`/team/${team._id}`}>{team._id} / {team.role}</Link></li>

const ListTeams = ({ teams }) => <ul>{teams.map(team => <Team key={team._id} team={team} />)}</ul>

const Group = (props) => <li><Link to={`/group/${props.team}`}>{props.group}</Link></li>

const ListGroups = (props) => <ul>{props.groups.map(group => <Group key={group} group={group} />)}</ul>

class User extends Component {
    constructor(props) {
        super(props)
        this.state = {
            _id: props.match.params.id_user,

            name: "",
            surname: "undefined",
            forename: "undefined",

            teams: [],
            id_lobby: null,

            curr_panel: null
        }
    }

    componentDidMount() {
        /*api.afetch('user/get', { id: this.state._id })
            .then(res => this.setState(res))
            .catch(err => this.handleCustomError(err, 'user/get'))*/
    }

    handleCustomError = (err, origin = false) => {
        switch (err.err) {
            default: {
                err.err ? console.log('user - api.err NOT HANDLE: ' + err.err + ' / ' + origin) : console.log('user - ERROR NOT FORMATED / ' + origin)
                console.log(err)
                break;
            }
        }
    }

    changePanel = (e) => {
        e.preventDefault()
        let name = e.target.name
        this.setState({ curr_panel: name })
    }

    render() {
        const is_user = this.props.userContext._id == this.state._id
        return <css.Container>
            <User_top
                is_user={is_user}
                username={this.state.name}
                surname={this.state.surname}
                forename={this.state.forename}
                country={this.state.country}
            />
            {
                this.state.id_lobby ? <div>in a lobby: <Link to={`/lobby/${this.state.id_lobby}`}>{this.state.id_lobby}</Link>{}</div> : null
            }
            <css.Menu>
                <button name="teams" onClick={this.changePanel} disabled={this.state.curr_panel == 'teams'}>TEAMS</button>
                <button name="events" onClick={this.changePanel} disabled={this.state.curr_panel == 'events'}>EVENTS</button>
                <button name="prizes" onClick={this.changePanel} disabled={this.state.curr_panel == 'prizes'}>PRIZES</button>
                <button name="games" onClick={this.changePanel} disabled={this.state.curr_panel == 'games'}>GAMES</button>
            </css.Menu>
            <div>
                {
                    this.state.curr_panel == 'teams' ? <ListTeams teams={this.state.teams} /> : <div>no panel</div>
                }
            </div>
        </css.Container >
    }
}

export default withAuth(User)