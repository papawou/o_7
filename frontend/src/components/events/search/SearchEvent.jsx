import React, { Component } from 'react';
import { Link } from 'react-router-dom'
import * as Filters from '../../filters/zob'
import * as api from '../../../utils/api'
import * as css from './css/SearchEvent'

const Event = (props) => {
    return <li>
        <Link to={`${props.id}`}>
            {props.id}
        </Link>
        <br />
        {props.name}
    </li>
}

const EventsList = (props) => {
    return <ul>
        {props.events.map(event => <Event key={event._id} id={event._id} name={event.name} />)}
    </ul>
}

class SearchEvent extends Component {
    constructor(props) {
        super(props)
        this.state = {
            name: "",
            id_game: "",
            platform: "",
            lang: "",

            event_mode: "",

            events: []
        }
    }

    componentDidMount() { this.searchEvents() }

    submitForm = (e) => {
        e.preventDefault()
        this.searchEvents()
    }

    searchEvents = () => {
        let data = JSON.parse(JSON.stringify(this.state))
        this.clearObject(data)
        api.afetch('event/search', data)
            .then(res => {
                this.setState({ events: res })
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
    handleChange = (e) => {
        let target = e.target
        if (target.type != 'checkbox')
            e.preventDefault()
        let name = target.name
        let value = target.type === 'checkbox' ? target.checked : target.type === 'select-multiple' ? Array.from(target.selectedOptions, option => option.value) : target.value
        this.setState({ [name]: value })
    }
    handleCustomError = (err, origin = false) => {
        switch (err.zob_err) {
            default: {
                err.zob_err ? console.log('searchEvent - zob_err NOT HANDLE:' + err.zob_err + ' / ' + origin) : console.log('searchEvent - ERROR NOT FORMATED / ' + origin)
                console.log(err)
                break;
            }
        }
    }

    render() {
        return <css.Container>
            <form onSubmit={this.submitForm}>
                <Filters.Games
                    id_game={this.state.id_game}
                    handleChange={this.handleChange}
                />
                <Filters.Platforms
                    plaform={this.state.platform}
                    handleChange={this.handleChange}
                />
                <br />
                <button type="submit">SEARCH EVENTS</button>
            </form>
            <div>
                <EventsList events={this.state.events} />
            </div>
        </css.Container >
    }
}

export default SearchEvent;