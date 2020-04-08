import React, { Component } from 'react';
//utils
import { Link } from 'react-router-dom'
import withLobby from '../../../contexts/Lobby'
import withAuth from '../../../contexts/Auth'
//components
import LobbyOverwatch from './lobbyGames/LobbyOverwatch'
import LobbySquad from './lobbyGames/LobbySquad'
//css
import * as css from './css/Lobby.js'

const Member = ({ id, name }) => <li><Link to={`/user/${id}`}>{name}</Link></li>

const MembersList = (props) => <ul>{props.members.map(member => <Member key={member._id} id={member._id} name={member.name} />)}</ul>

class Lobby extends Component {
    constructor(props) {
        super(props)
        this.state = {
            need_validate: false
        }
        this.games = {
            squad: LobbySquad,
            overwatch: LobbyOverwatch
        }
    }

    componentDidMount() {
        if (this.props.lobbyContext.inited && this.props.lobbyContext._id != this.props.match.params.id_lobby) {
            if (this.props.lobbyContext._id) {
                this.setState({ need_validate: true })
            }
            else {
                this.props.lobbyContext.joinLobby(this.props.match.params.id_lobby)
            }
        }
    }

    componentDidUpdate(prevProps, prevState) {
        if (prevProps.lobbyContext.inited != this.props.lobbyContext.inited && this.props.lobbyContext.inited && this.props.lobbyContext._id != this.props.match.params.id_lobby)
            if (this.props.lobbyContext._id) {
                this.setState({ need_validate: true })
            }
            else {
                this.props.lobbyContext.joinLobby(this.props.match.params.id_lobby)
            }
    }

    validateJoin = (e) => {
        e.preventDefault()
        this.props.lobbyContext.joinLobby(this.props.match.params.id_lobby)
        this.setState({ need_validate: false })
    }

    render() {
        let LobbyGame
        if (this.props.lobbyContext.id_game != null)
            LobbyGame = this.games[this.props.lobbyContext.id_game]

        return <css.Container>
            {this.props.lobbyContext.id_game != null && !this.state.need_validate ?
                <React.Fragment>
                    ID = {this.props.lobbyContext._id} {`${this.props.lobbyContext.members.length} / ${this.props.lobbyContext.size}`}< br />
                    <MembersList members={this.props.lobbyContext.members} />
                    <LobbyGame
                        handleClick={this.props.lobbyContext.handleClick}
                        cvs={this.props.lobbyContext.cvs}
                        id_user={this.props.userContext._id}
                        members={this.props.lobbyContext.members}
                    />
                </React.Fragment>
                : this.state.need_validate ?
                    <button onClick={this.validateJoin}>LEAVE CURRENT LOBBY ?</button>
                    : <div>NO LOBBY GAME</div>
            }
        </css.Container>
    }
}

export default withLobby(withAuth(Lobby));