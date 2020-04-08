import React, { Component } from 'react';
import { Link } from 'react-router-dom'
//utils
import withLobby from '../../contexts/Lobby'
import withAuth from '../../contexts/Auth'
import _io from '../../utils/socketio'

import * as _eventrules from './Test/events'
//css
import * as css from './css/LobbyFooter'


const UserLobby = (props) => <React.Fragment>
    <Link to={props.id_lobby ? `/lobby/${props.id_lobby}` : '#'}>{props.id_lobby}</Link>
    <button name="exitLobby" onClick={props.exitLobby}>EXIT LOBBY</button>
</React.Fragment>

class LobbyFooter extends Component {
    constructor(props) {
        super(props)
        this.state = {
        }
    }

    emitDebug = (e) => {
        e.preventDefault()
        this.props.userContext.io.emit('DEBUG')
    }

    emitDebugLobby = (e) => {
        e.preventDefault()
        this.props.lobbyContext.io.emit('DEBUG')
    }

    test = (e) => {
        e.preventDefault()
        let event = {
            "_id": "5bc8ad97d1b18822e9176a2e",
            "owner": { "type": "users", "_id": "5bb001684f26050ca0823b8e", "publisher": { "_id": "5bb001684f26050ca0823b8e", "name": "papawa" }, "name": "papawa" }, "id_game": "overwatch", "platform": "xbox 360", "event_mode": "default", "datetime_start": "2018-10-18T15:56:16.810Z", "datetime_end": "2018-10-18T15:56:16.810Z",
            rules: [{ id: "privacy", value: "followers" }, { id: "privacy", value: "invitation" }, { id: "privacy", value: "followers" }]
        }
        let queries = {}
        //init conditions
        try {
            event.rules.map(rule => {
                let query = _eventrules[rule.id](rule.value, event)
                if (queries[query.input])
                    queries[query.input].push(query.query)
                else
                    queries[query.input] = [query.query]
            })
        }
        catch (err) {
            console.log(err)
        }
        console.log(queries)
        //init group
        queries = _eventrules.generateQueries(queries, event)
        console.log(queries)
    }

    render() {
        return <css.Container>
            {
                this.props.lobbyContext._id ?
                    <UserLobby
                        id_lobby={this.props.lobbyContext._id}
                        exitLobby={this.props.lobbyContext.handleClick}
                    /> :
                    <div>NOT IN A LOBBY</div>
            }
            <button onClick={this.emitDebug}>DEBUG IO</button>
            <button onClick={this.props.userContext.openIo}>OPEN IO</button>
            <button onClick={this.props.userContext.closeIo}>CLOSE IO</button> <br />
            <button onClick={this.emitDebugLobby}>DEBUG /LOBBYS</button>
            <button onClick={() => { this.props.lobbyContext.io.open() }}>OPEN LOBBYS</button>
            <button onClick={() => { this.props.lobbyContext.io.close() }}>CLOSE IO</button> <br />
            <button onClick={() => { _io.open() }}>OPEN MANAGER</button>
            <button onClick={() => { _io.close() }}>CLOSE MANAGER</button>
            <button onClick={this.test}>TEST</button>
        </css.Container >
    }
}

export default withAuth(withLobby(LobbyFooter))