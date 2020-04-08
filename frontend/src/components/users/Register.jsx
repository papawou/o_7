import React, { Component } from 'react'
import * as api from '../../utils/api'
//CSS
import styled from 'styled-components'

const SContainer = styled.div`
    grid-area:content;
`

class Register extends Component {
    constructor(props) {
        super(props)
        this.state = {
            username: undefined,
            password: undefined,
            email: undefined,
            id_tag: undefined
            /*
            additionnal
            //ONESHOT
                unmodifiable
            //LATERSET
                sexe
                birth
                localisation
            */
        }
    }

    submitForm = (e) => {
        e.preventDefault()
        let data = this.state
        api.afetch('register', data)
            .then(res => console.log(res))
            .catch(err => this.handleCustomError(err, 'submitForm'))
    }

    handleCustomError = (err, origin = false) => {
        switch (err.err) {
            default: {
                err.err ? console.log('register - api.err NOT HANDLE:' + err.err + ' / ' + origin) : console.log('register - ERROR NOT FORMATED / ' + origin)
                console.log(err)
                break;
            }
        }
    }

    render() {
        return <SContainer>
            <form onSubmit={this.submitForm}>
                <input placeholder="@id_tag" name="id_tag" value={this.state.id_tag} />
                <input placeholder="username" name="username" value={this.state.username} />
                <input placeholder="password" name="password" value={this.state.password} />
                <input placeholder="email" name="email" value={this.state.email} />
                <button type="submit">REGISTER</button>
            </form>
        </SContainer>
    }
}

export default Register;