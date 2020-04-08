import React, { Component } from 'react';
import { Link } from 'react-router-dom'

import * as api from '../../../utils/api'
import * as Filters from '../../filters/zob'
//css
import * as css from './css/SearchTeam'

const Team = (props) => {
    return <li>
        <Link to={`${props.id}`}>
            {props.id}
        </Link>
        <br />
        {props.name}
    </li>
}

const TeamsList = (props) => {
    return <ul>
        {props.teams.map(team => <Team key={team._id} id={team._id} name={team.name} />)}
    </ul>
}

class SearchTeam extends Component {
    constructor(props) {
        super(props)
        this.state = {
            teams: [],
            name: "",
            lang: "",
            platform: "",
            is_fresh: false
        }
    }

    componentDidMount() {
        this.searchTeams()
    }

    handleChange = (e) => {
        e.preventDefault()
        let target = e.target
        let name = target.name
        let value = target.type === 'checkbox' ? target.checked : target.type === 'select-multiple' ? Array.from(target.selectedOptions, option => option.value) : target.value

        this.setState({ [name]: value })
    }

    submitForm = (e) => {
        e.preventDefault()
        this.searchTeams()
    }

    searchTeams = () => {
        let data = JSON.parse(JSON.stringify(this.state))
        delete data.teams
        delete data.is_fresh
        this.clearObject(data)
        
        api.afetch('team/search', data)
            .then(res => {
                this.setState({ teams: res })
            })
            .catch(err => this.handleCustomError(err))
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

    handleCustomError = (err) => {
        switch (err.zob_err) {
            default: {
                err.zob_err ? console.log('ERRCODE NOT HANDLE: ' + err.zob_err) : console.log('ERRCODE NOT FORMATTED')
                break;
            }
        }
        console.log(err)
    }

    render() {
        return <css.Container>
            <form onSubmit={this.submitForm}>
                <input type="text" placeholder="teamname" name="name" onChange={this.handleChange} />
                <Filters.Langs handleChange={this.handleChange} lang={this.state.lang} />
                <button type="submit">SEARCH TEAMS{this.state.is_fresh ? "" : "*"}</button>
            </form>
            {
                this.state.teams.length > 0 ?
                    <TeamsList teams={this.state.teams} /> :
                    "NO TEAMS FOUND"
            }
        </css.Container>
    }
}

export default SearchTeam