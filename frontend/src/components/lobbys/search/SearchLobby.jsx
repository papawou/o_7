import React, { Component } from 'react';
import { Link } from 'react-router-dom'
import * as api from '../../../utils/api'

import SearchOverwatch from './searchGames/SearchOverwatch'
import SearchSquad from './searchGames/SearchSquad'

import * as Filters from '../../filters/zob'
import * as css from './css/SearchLobby'

const Lobby = ({ id, name }) =>
    <li>
        <Link to={`${id}`}>
            {id}
        </Link>
        <br />
        {name}
    </li>

const LobbysList = (props) =>
    <ul>
        {props.lobbys.map(lobby => <Lobby key={lobby._id} id={lobby._id} name={lobby.name} />)}
    </ul>

class SearchLobby extends Component {
    constructor(props) {
        super(props)
        this.state = {
            id_game: '',
            //zob filter
            name: "",
            social: { id: 'none', mic: false, sound: false },
            lang: "",
            mentality: '',
            //game filter
            config: {},
            cv: {},
            platform: "",
            //data
            lobbys: [],
            //utils
            datagame: null,
            inited: false
        }

        this.games = {
            'squad': SearchSquad,
            'overwatch': SearchOverwatch
        }
    }

    componentDidMount() {
        if (this.state.id_game != "")
            this.changeDatagame(this.state.id_game)
    }

    componentDidUpdate(prevProps, prevState) {
        if (prevState.id_game != this.state.id_game && this.state.id_game != "") {
            this.changeDatagame(this.state.id_game)
        }
    }

    handleChange = (e) => {
        let target = e.target
        if (target.type == 'checkbox')
            e.preventDefault()
        let name = target.name
        let value = target.type === 'checkbox' ? target.checked : target.type === 'select-multiple' ? Array.from(target.selectedOptions, option => option.value) : target.value

        this.setState({ [name]: value })
    }

    handleCustomError = (err) => {
        switch (err.err) {
            default: {
                err.err ? console.log('ERRCODE NOT HANDLE: ' + err.err) : console.log('ERRCODE NOT FORMATTED')
                break;
            }
        }
        console.log(err)
    }

    changeGame = (e) => {
        e.preventDefault()
        this.setState({ id_game: e.target.value, inited: false })
    }

    changeDatagame = (id_game) => {
        api.getfetch('/data/datagames/' + id_game + '.json')
            .then(res => {
                this.setState({
                    id_game: id_game,
                    config: res.default.config,
                    cv: res.default.cv,
                    platform: '',
                    datagame: res,
                    inited: true
                })
            })
            .catch(err => this.handleCustomError(err, 'changeDatagame'))
    }

    submitForm = (e) => {
        e.preventDefault()
        this.searchLobbys()
    }

    clearObject = (object) => {
        let needDelete = false
        let isArray = Array.isArray(object)
        for (let [key, value] of isArray ? object.entries() : Object.entries(object)) {
            needDelete = false
            if (typeof value === 'object') {
                if (Array.isArray(value)) {
                    if (value.length == 0)
                        needDelete = true
                    else
                        if (typeof value[0] === 'object') {
                            this.clearObject(value)
                            if (value.length == 0)
                                needDelete = true
                        }
                }
                else {
                    if (Object.keys(value).length != 0)
                        this.clearObject(value)
                    if (Object.keys(value).length == 0)
                        needDelete = true
                }
            }
            else
                if (!value && typeof value != 'boolean' && typeof value != 'number')
                    needDelete = true

            if (needDelete)
                if (isArray)
                    object.splice(key, 1)
                else
                    delete object[key]
        }
    }

    searchLobbys = () => {
        let data = JSON.parse(JSON.stringify(this.state))
        delete data.inited
        delete data.datagame
        delete data.lobbys
        if (JSON.stringify(data.cv) == JSON.stringify(this.state.datagame.default.cv))
            delete data.cv

        this.clearObject(data)
        api.afetch('lobby/search', data)
            .then(res => {
                this.setState({ lobbys: res })
            })
            .catch(err => this.handleCustomError(err))
    }

    updateConfig = (config) => {
        this.setState(prevState => ({ config: { ...prevState.config, ...config } }))
    }

    updateCv = (cv) => {
        this.setState(prevState => ({ cv: { ...prevState.cv, ...cv } }))
    }

    changeSocial = (e) => {
        let target = e.target
        if (target.type != 'checkbox')
            e.preventDefault()
        let name = target.name
        let value = target.type === 'checkbox' ? target.checked : target.value
        if (name == "id" && value == "none")
            this.setState({ social: { id: "none", mic: false, sound: false }, lang: "" })
        else if (name == "sound" && !value)
            this.setState(prevState => ({ social: { ...prevState.social, mic: false, sound: false } }))
        else if (name == "mic" && value)
            this.setState(prevState => ({ social: { ...prevState.social, mic: true, sound: true } }))
        else
            this.setState(prevState => ({ social: { ...prevState.social, [name]: value } }))
    }

    render() {
        let SearchGame
        if (this.state.id_game != null)
            SearchGame = this.games[this.state.id_game]
        let formOk
        if (this.state.id_game && this.state.platform)
            formOk = true
        else
            formOk = false
        return <css.Container>
            <form onSubmit={this.submitForm}>
                <div>
                    ZOB FILTERS <br />
                    <Filters.Social
                        id={this.state.social.id}
                        mic={this.state.social.mic}
                        sound={this.state.social.sound}
                        handleChange={this.changeSocial}
                    />
                    <Filters.Langs
                        lang={this.state.lang}
                        disabled={this.state.social.id == 'none'}
                        handleChange={this.changeSocial}
                    />
                    <br />
                    <Filters.Mentalities
                        mentality={this.state.mentality}
                        handleChange={this.handleChange}
                    />
                    <br />
                    <Filters.Games
                        id_game={this.state.id_game}
                        handleChange={this.changeGame}
                    />
                </div>
                <div>FILTER GAME - {this.state.id_game}</div>
                {this.state.inited &&
                    <SearchGame
                        datagame={this.state.datagame}
                        config={this.state.config}
                        cv={this.state.cv.config}
                        platform={this.state.platform}

                        updateConfig={this.updateConfig}
                        updateCv={this.updateCv}
                        updateState={this.handleChange}
                    />
                }
                <br />
                <button type="submit" disabled={!formOk}>SEARCH LOBBYS</button>
            </form>
            <br />
            {
                this.state.lobbys.length > 0 ?
                    <LobbysList lobbys={this.state.lobbys} /> :
                    "NO LOBBYS FOUND"
            }
        </css.Container>
    }
}

export default SearchLobby