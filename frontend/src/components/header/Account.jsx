import React, { Component, Fragment } from 'react'
import { Link } from 'react-router-dom'
//utils
import withAuth from '../../contexts/Auth'
//CSS
import * as css from './css/Account'

////
const Guest = (props) => {
    return <div>
        <form onSubmit={props.submitForm}>
            <input onChange={props.handleChange} type="text" name="name" placeholder="USERNAME" value={props.name} />
            <input onChange={props.handleChange} type="password" name="password" placeholder="*****" value={props.password} />
            <button type="submit">CONNECT</button>
        </form>
        <Link to={`/register`}><button type="button">REGISTER</button></Link>
    </div >
}

const User = (props) => (
    <Fragment>
        <Link to={`/user/${props.id}`}><button type="button">{props.name}</button></Link>
        <button onClick={props.logout}>LOGOUT</button>
    </Fragment>)

class Account extends Component {
    constructor(props) {
        super(props)
        this.state = {
            name: '',
            password: ''
        }
    }

    submitForm = (e) => {
        e.preventDefault()
        console.log(this.state.name)
        this.props.userContext.login(this.state.name, this.state.password)
            .catch(err => { alert('ACCOUNT_HEADER FAILED LOGIN') })
    }

    handleChange = (e) => {
        e.preventDefault()
        let newState = {}
        newState[e.target.name] = e.target.value
        this.setState(newState)
    }

    render() {
        return <css.Container>
            {this.props.userContext.logged ?
                <User
                    id={this.props.userContext._id}
                    name={this.props.userContext.name}
                    logout={this.props.userContext.logout}
                /> :
                <Guest
                    submitForm={this.submitForm}
                    handleChange={this.handleChange}
                    name={this.state.name}
                    password={this.state.password} />
            }
        </css.Container>
    }
}

export default withAuth(Account);