import React, { Component } from 'react';

import withAuth from '../../../contexts/Auth'
import withLobby from '../../../contexts/Lobby'
import * as api from '../../../utils/api'

import CreateOverwatch from './createGames/CreateOverwatch'
import CreateSquad from './createGames/CreateSquad'

import * as Filters from '../../filters/zob'

import * as css from './css/CreateLobby.js'

const FieldLobbyName = ({ name, handleChange }) => {
    return <label>
        NAME:<br />
        <input type="text" name="name"
            onChange={handleChange}
            value={name}
            placeholder="Lobby Name" />
    </label>
}

const Social = ({ social, lang, handleChange }) =>
    <div>
        <Filters.Social
            id={social.id}
            mic={social.mic}
            sound={social.sound}

            handleChange={handleChange}
        />
        <Filters.Langs
            lang={lang}
            disabled={social.id == "none"}
            handleChange={handleChange}
        />
        <input type="text" name="url" disabled={social.id == 'none'} value={social.url} placeholder="**url_social**" onChange={handleChange} />
    </div>

class CreateLobby extends Component {
    constructor(props) {
        super(props)
        this.state = {
            id_game: "",
            name: `Lobby de ${this.props.userContext.name}`,

            social: { id: "none", url: "", mic: false, sound: false },
            lang: "",
            mentality: '',
            tags: [],
            //game filter
            platform: "",
            config: {},
            cvs: [],
            //utils
            cv_owner: 0,
            inited: false,
            datagame: null,
        }
        this.count_cvs = 1
        this.games = {
            squad: CreateSquad,
            overwatch: CreateOverwatch
        }
    }

    getCount = () => this.count_cvs++

    componentDidMount() {
        if (this.state.id_game != "")
            this.changeDatagame(this.state.id_game)
    }

    componentDidUpdate(prevProps, prevState) {
        if (prevState.id_game != this.state.id_game && this.state.id_game != "") {
            this.changeDatagame(this.state.id_game)
        }
    }

    submitForm = (e) => {
        e.preventDefault()
        let data = JSON.parse(JSON.stringify(this.state))
        delete data.datagame
        delete data.inited
        data.size = data.cvs.length

        let cv_index = data.cvs.findIndex(cv => cv.id == data.cv_owner)
        if (cv_index > -1) {
            data.cv_owner = data.cvs.splice(cv_index, 1)[0]
            delete data.cv_owner.id
            if (JSON.stringify(data.cv_owner) == JSON.stringify(this.state.datagame.default.cv))
                delete data.cv_owner
        }
        else {
            delete data.cv_owner
        }

        data.cvs = data.cvs.filter(cv => {
            delete cv.id
            return JSON.stringify(cv) != JSON.stringify(this.state.datagame.default.cv)
        })

        this.props.lobbyContext.createLobby(data)
            .then(id_lobby => {
                this.props.history.push(`/lobby/${id_lobby}`)
            })
            .catch(err => {
                this.handleCustomError(err, 'submitForm')
            })
    }

    handleChange = (e) => {
        let target = e.target
        if (target.type != 'checkbox')
            e.preventDefault()
        let name = target.name
        let value = target.type === 'checkbox' ? target.checked : target.type === 'select-multiple' ? Array.from(target.selectedOptions, option => option.value) : target.value

        this.setState({ [name]: value })
    }

    handleCheck = (value, id_cv) => this.setState({ cv_owner: value ? id_cv : 0 })

    changeSocial = (e) => {
        let target = e.target
        if (target.type != 'checkbox')
            e.preventDefault()
        let name = target.name
        let value = target.type === 'checkbox' ? target.checked : target.value
        if (name == "id" && value == "none")
            this.setState({ social: { id: "none", url: "", mic: false, sound: false }, lang: "" })
        else if (name == "sound" && !value)
            this.setState(prevState => ({ social: { ...prevState.social, mic: false, sound: false } }))
        else if (name == "mic" && value)
            this.setState(prevState => ({ social: { ...prevState.social, mic: true, sound: true } }))
        else
            this.setState(prevState => ({ social: { ...prevState.social, [name]: value } }))
    }

    changeGame = (e) => {
        e.preventDefault()
        this.setState({ inited: false, id_game: e.target.value })
    }
    changeDatagame = (id_game) => {
        api.getfetch('/data/datagames/' + id_game + '.json')
            .then(res => {
                this.setState({
                    id_game: res.id_game,
                    config: res.default.config,
                    cvs: [{ id: this.getCount(), ...res.default.cv }, { id: this.getCount(), ...res.default.cv }],

                    datagame: res,
                    inited: true
                })
            })
            .catch(err => this.handleCustomError(err, 'changeDatagame'))
    }

    updateConfig = (config) => {
        this.setState(prevState => ({ config: { ...prevState.config, ...config } }))
    }
    addCvs = (cvs) => {
        let cvs_counted = cvs.map(cv => ({ id: this.getCount(), ...cv }))
        this.setState(prevState => ({
            cvs: [...prevState.cvs, ...cvs_counted]
        }))
    }
    deleteCv = (id_cv) => {
        this.setState(prevState => {
            let index = prevState.cvs.findIndex(cv => cv.id == id_cv)
            return {
                cvs: [
                    ...prevState.cvs.slice(0, index),
                    ...prevState.cvs.slice(index + 1)
                ]
            }
        })
    }
    deleteCvs = (index) => {
        this.setState(prevState => ({
            cvs: prevState.cvs.slice(0, index)
        }))
    }
    setCv = (id_cv, data) => {
        this.setState(prevState => {
            let index = prevState.cvs.findIndex(cv => cv.id == id_cv)
            return {
                cvs: [
                    ...prevState.cvs.slice(0, index),
                    { ...prevState.cvs[index], ...data },
                    ...prevState.cvs.slice(index + 1)
                ]
            }
        })
    }
    handleCustomError = (err, origin = false) => {
        switch (err.zob_err) {
            default: {
                err.zob_err ? console.log('createLobby - zob_err NOT HANDLE:' + err.zob_err + ' / ' + origin) : console.log('createLobby - ERROR NOT FORMATED / ' + origin)
                console.log(err)
                break;
            }
        }
    }

    render() {
        let CreateGame
        if (this.state.id_game != "")
            CreateGame = this.games[this.state.id_game]
        let formOk
        if (this.props.userContext.logged && this.state.id_game && this.state.name && this.state.platform)
            formOk = true
        else
            formOk = false
        return <css.Container>
            <form onSubmit={this.submitForm}>
                <FieldLobbyName
                    name={this.state.name}
                    handleChange={this.handleChange}
                />
                <br />
                <Social
                    social={this.state.social}
                    lang={this.state.lang}
                    handleChange={this.changeSocial}
                />
                <Filters.Mentalities
                    mentality={this.state.mentality}
                    handleChange={this.handleChange}
                />
                <br />
                <br />
                <Filters.Games
                    id_game={this.state.id_game}
                    handleChange={this.changeGame}
                />
                <div>FILTERGAME - {this.state.id_game}</div>
                {this.state.inited &&
                    <CreateGame
                        datagame={this.state.datagame}
                        cvs={this.state.cvs}
                        cv_owner={this.state.cv_owner}
                        config={this.state.config}
                        platform={this.state.platform}

                        handleCheck={this.handleCheck}
                        updateState={this.handleChange}
                        updateConfig={this.updateConfig}

                        addCvs={this.addCvs}
                        deleteCv={this.deleteCv}
                        deleteCvs={this.deleteCvs}
                        setCv={this.setCv}
                    />
                }
                <button type="submit" disabled={!formOk}>CREATE LOBBY</button>
            </form>
        </css.Container >
    }
}

export default withAuth(withLobby(CreateLobby));