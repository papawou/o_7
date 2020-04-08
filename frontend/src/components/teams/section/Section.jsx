import React, { Component } from 'react';

import * as api from '../../../utils/api'
import * as css from './css/Section'

class Section extends Component {
    constructor(props) {
        super(props)
        this.state = {
            _id: this.props.match.params.id_section
        }
    }

    componentDidMount() {
        api.afetch('section/get', { id: this.state._id })
            .then(section => {
                console.log(section)
                this.setState(section)
            })
            .catch(err => this.handleCustomError(err, 'team/get'))
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
                err.zob_err ? console.log('section - zob_err NOT HANDLE:' + err.zob_err + ' / ' + origin) : console.log('section - ERROR NOT FORMATED / ' + origin)
                console.log(err)
                break;
            }
        }
    }

    render() {
        return <css.Container>
            SECTION
        </css.Container >
    }
}

export default Section;