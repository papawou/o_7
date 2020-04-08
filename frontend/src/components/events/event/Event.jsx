import React, { Component } from 'react';
import { Link, Route, Switch } from 'react-router-dom'
import * as api from '../../../utils/api'
import * as css from './css/Event'
import withAuth from '../../../contexts/Auth';

import Requests from './panels/Requests'

const Main = () =>
    <div>
        MAIN PANEL
    </div>

const Test = () =>
    <div>
        TEST PANEL
    </div>

const Member = ({ member }) =>
    <li>
        <Link to={`/user/${member._id}`}>{member.name}</Link>
        <br />
        {JSON.stringify(member.roles)}
    </li>

const MembersList = ({ members }) =>
    <ul>
        {members.map(member => <Member key={member._id} member={member} />)}
    </ul>

class Event extends Component {
    constructor(props) {
        super(props)
        this.state = {
            _id: this.props.match.params.id_event,
            event_mode: "",
            id_game: "",
            platform: "",
            members: [],
            owner: { _id: "", name: "" },
            inited: false
        }
    }

    componentDidMount() {
        api.afetch('event/get', { id: this.state._id })
            .then(event => {
                console.log(event)
                this.setState({ ...event, inited: true })
            })
            .catch(err => this.handleCustomError(err, 'event/get'))
    }

    componentDidUpdate(prevProps, prevState) {
        if (prevProps.match.params.id_event != this.props.match.params.id_event)
            this.setState({ _id: this.props.match.params.id_event, inited: false })
        else if (prevState.inited != this.state.inited && !this.state.inited) {
            api.afetch('event/get', { id: this.state._id })
                .then(event => {
                    console.log('didu Event')
                    this.setState({ ...event, inited: true })
                })
                .catch(err => {
                    this.handleCustomError(err, 'event/get')
                    this.setState({ inited: false })
                })
        }
    }

    joinEvent = (e) => {
        e.preventDefault()
        this.props.userContext.authfetch('event/join', { _id: this.state._id })
            .then(res => console.log(res))
            .catch(err => this.handleCustomError(err, 'joinEvent'))
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
                err.zob_err ? console.log('event - zob_err NOT HANDLE:' + err.zob_err + ' / ' + origin) : console.log('event - ERROR NOT FORMATED / ' + origin)
                console.log(err)
                break;
            }
        }
    }

    render() {
        let event = this.props.userContext.events.find(event => event._id == this.state._id)
        let roles = []
        if (event)
            roles = event.roles
        return <css.Container>
            Name: {this.state.name}
            <br />
            <Link to={this.props.match.url}>HOME</Link> <Link to={`${this.props.match.url}/requests`}>REQUESTS</Link>
            <Switch>
                <Route exact path={`${this.props.match.path}`} component={Main} />
                <Route path={`${this.props.match.path}/requests`} component={Requests} />
            </Switch>
        </css.Container >
    }
}

export default withAuth(Event);