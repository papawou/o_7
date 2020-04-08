import React, { Component } from 'react';

import * as api from '../../../utils/api'
import withAuth from '../../../contexts/Auth'

import _event from '../../../data/event.js'

import * as Filters from '../../filters/zob'

import * as css from './css/CreateEvent'

const InputTextName = ({ name, handleChange }) =>
    <label>
        <input type="text" name="name"
            onChange={handleChange}
            value={name}
            placeholder="Event Name" />
    </label>

class CreateEvent extends Component {
    constructor(props) {
        super(props)
        this.state = {
            name: "",
            owner: `users:${this.props.userContext._id}`,
            id_game: "",
            platform: "",
            event_mode: "default",
            datetime_start: new Date(),
            datetime_end: new Date(),
            visibility: "public",
            request_check: true,

            //RULES?
            privacy: "none",

            inited: false,
            datagame: null
        }

        this.games = {}
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

    getCategoryOwner = () => this.state.owner.slice(0, this.state.owner.indexOf(':'))
    getOwners = () => {
        let options = []
        for (let team of this.props.userContext.teams) {
            options.push(<option key={team._id} value={`teams:${team._id}`}>{team.name}</option>)
            for (let section of team.sections)
                options.push(<option key={section._id} value={`sections:${section._id}`}>{`${team.name} - ${section.name}`}</option>)
        }
        return options
    }
    getPrivacies = () => [
        ..._event.privacies.default.map(privacy => <option key={privacy} value={privacy}>{privacy}</option>),
        _event.privacies[this.getCategoryOwner()].map(privacy => <option key={privacy} value={privacy}>{privacy}</option>)
    ]

    changeDatagame = (id_game) => {
        api.getfetch('/data/datagames/' + id_game + '.json')
            .then(res => {
                this.setState({
                    id_game: res.id_game,

                    datagame: res,
                    inited: true
                })
            })
            .catch(err => this.handleCustomError(err, 'changeDatagame'))
    }
    changeGame = (e) => {
        e.preventDefault()
        this.setState({ inited: false, id_game: e.target.value })
    }
    changeEventMode = (e) => {
        e.preventDefault()
        this.setState({ event_mode: e.target.value })
    }

    changeOwner = (e) => {
        e.preventDefault()
        let target = e.target
        let name = target.name
        let value = target.value

        this.setState({ [name]: value, privacy: "none" })
    }

    handleChange = (e) => {
        let target = e.target
        if (target.type != 'checkbox')
            e.preventDefault()
        let name = target.name
        let value = target.type === 'checkbox' ? target.checked : target.type === 'select-multiple' ? Array.from(target.selectedOptions, option => option.value) : target.value
        if (name == "datetime_start") {
            try {
                if (!value)
                    throw ('invalid')
                value = new Date(value)
            }
            catch (e) {
                console.log('error' + e)
                value = new Date()
            }
        }
        this.setState({ [name]: value })
    }
    handleCustomError = (err, origin = false) => {
        switch (err.zob_err) {
            default: {
                err.zob_err ? console.log('createEvent - zob_err NOT HANDLE:' + err.zob_err + ' / ' + origin) : console.log('createEvent - ERROR NOT FORMATED / ' + origin)
                console.log(err)
                break;
            }
        }
    }

    toDatetimeLocal = (date) => {
        let ten = (i) => {
            return (i < 10 ? '0' : '') + i;
        },
            YYYY = date.getFullYear(),
            MM = ten(date.getMonth() + 1),
            DD = ten(date.getDate()),
            HH = ten(date.getHours()),
            II = ten(date.getMinutes()),
            SS = ten(date.getSeconds());
        return YYYY + '-' + MM + '-' + DD + 'T' + HH + ':' + II + ':' + SS
    }

    submitForm = (e) => {
        e.preventDefault()
        let data = JSON.parse(JSON.stringify(this.state))
        delete data.datagame
        delete data.inited
        data.owner = { type: data.owner.slice(0, data.owner.indexOf(':')), _id: data.owner.slice(data.owner.indexOf(':') + 1) }
        console.log(data)
        this.props.userContext.authfetch('event/create', data)
            .then(res => console.log(res))
            .catch(error => this.handleCustomError(error))
    }

    render() {
        let CreateGame
        if (this.state.id_game != "") {
            //init module Event.create
            CreateGame = this.games[this.state.id_game]
        }
        return <css.Container>
            <InputTextName
                name={this.state.name}
                handleChange={this.handleChange}
            />
            <br />
            <select name="event_mode" value={this.state.event_mode} onChange={this.changeEventMode}>
                {_event.event_modes.map(event_mode => <option key={event_mode} value={event_mode}>{event_mode}</option>)}
            </select>
            <br />
            <Filters.Games
                id_game={this.state.id_game}
                handleChange={this.changeGame}
            />
            {/*
                this.state.inited ?
                    (CreateGame != undefined ?
                        <CreateGame /> :
                        <div>CREATE GAME UNDEFINED</div>
                    ) :
                    <div>CHOOSE A GAME</div>
            */}
            <div>
                <Filters.Platforms
                    platform={this.state.platform}
                    handleChange={this.handleChange}
                />
                <br />
                <select name="owner" value={this.state.owner} onChange={this.changeOwner}>
                    <option value={`users:${this.props.userContext._id}`}>{this.props.userContext.name}</option>
                    {this.getOwners()}
                </select>
                <select name="visibility" value={this.state.visibility} onChange={this.handleChange}>
                    <option value="public">public</option>
                    <option value="private">private</option>
                </select>
                <br />
                DATETIME_START
                <input type="datetime-local" name="datetime_start" value={this.toDatetimeLocal(this.state.datetime_start)}
                    onChange={this.handleChange}
                />
                <br />
                DATETIME_END
                <input type="datetime-local" name="datetime_end" value={this.toDatetimeLocal(this.state.datetime_end)}
                    onChange={this.handleChange}
                />
                <br/>
                <label>request_check: <input type="checkbox" name="request_check" checked={this.state.request_check} onChange={this.handleChange}/></label>
                <div>
                    //RULES<br/>
                    privacy: <select name="privacy" value={this.state.privacy} onChange={this.handleChange}>
                        {this.getPrivacies()}
                    </select>
                </div>
            </div>
            <button onClick={this.submitForm}>CREATE EVENT</button>
        </css.Container >
    }
}

export default withAuth(CreateEvent);