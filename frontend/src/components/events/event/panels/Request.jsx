import React from 'react'
import withAuth from '../../../../contexts/Auth';
import { Link, Route, Switch } from 'react-router-dom'

class Request extends React.Component {
    constructor(props) {
        super(props)
        this.state = {
            name: ""
        }
    }

    componentDidMount() {
        this.props.userContext.authfetch('event/request/get', { id_event: this.props.id_event, id_request: this.props.id })
            .then(request => {
                console.log(request)
                this.setState(request)
            })
            .catch(err => console.log(err))
    }

    accept = (e) => {
        e.preventDefault()
        this.props.userContext.authfetch('event/request/accept', { id_event: this.props.id_event, id_request: this.props.id })
            .then(res => {
                console.log(res)
            })
            .catch(err => console.log(err))
    }

    reject = (e) => {
        e.preventDefault()
        this.props.userContext.authfetch('event/request/reject', { id_event: this.props.id_event, id_request: this.props.id })
            .then(res => {
                console.log(res)
            })
            .catch(err => console.log(err))
    }

    render() {
        return <div>
            <br />
            REQUEST - {this.state._id}
            <br />
            {this.state.name}
            <br />
            <button onClick={this.accept}>ACCEPT REQUEST</button>
            <button onClick={this.reject}>REJECT REQUEST</button>
        </div>
    }
}

export default withAuth(Request)