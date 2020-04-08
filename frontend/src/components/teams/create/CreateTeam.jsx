import React, { Component } from 'react'
//contexts
import withAuth from '../../../contexts/Auth'

import * as Filters from '../../filters/zob'

//css
import * as css from './css/CreateTeam.js'

const Social = ({ social, url, handleChange }) =>
    <div>
        <Filters.Social
            id={social.id}
            mic={social.mic}
            sound={social.sound}
            handleChange={handleChange}
        />
        <input type="text" name="url" disabled={social.id == 'none'} value={url} placeholder="**url_social**" onChange={handleChange} />
    </div>

const Section = ({ id_game, name, handleChange, handleDelete }) =>
    <div>
        <Filters.Games
            id_game={id_game}
            handleChange={handleChange}
        />
        <input type="text" name="name"
            onChange={handleChange}
            value={name}
            placeholder="Section name" />
        <button onClick={handleDelete}>DELETE SECTION</button>
    </div>

const Sections = ({ sections, addSection, changeSection, deleteSection }) =>
    <div>
        {
            sections.map(section =>
                <Section
                    key={section.id}
                    id_game={section.id_game}
                    name={section.name}
                    handleChange={(e) => changeSection(e, section.id)}
                    handleDelete={(e) => deleteSection(e, section.id)}
                />)
        }
        <button onClick={addSection}>ADD SECTION</button>
    </div>

const FieldPrefix = ({ prefix, handleChange }) =>
    <input type="text" name="prefix"
        onChange={handleChange}
        value={prefix}
        placeholder="Prefix name"
    />


const FieldTeamName = ({ name, handleChange }) =>
    <input type="text" name="name"
        onChange={handleChange}
        value={name}
        placeholder="Team name" />

class CreateTeam extends Component {
    constructor(props) {
        super(props)
        this.state = {
            name: "",
            prefix: "",
            lang: "",
            platform: "",
            sections: [],
            social: { id: "none", url: "", mic: false, sound: false }
        }
        this.count_sections = 0
    }

    submitForm = (e) => {
        e.preventDefault()
        let data = JSON.parse(JSON.stringify(this.state))
        data.sections = data.sections.filter(section => section.id_game ? true : false)
        console.log(data)
        this.props.userContext.authfetch('team/create', data)
            .then(res => {
                this.props.history.push(`/team/${res.id_team}`)
            })
            .catch(err => this.handleCustomError(err, 'team/create'))
    }

    addSection = (e) => {
        e.preventDefault()
        this.setState(prevState => ({ sections: [...prevState.sections, { id: this.count_sections++, id_game: "", name: "" }] }))
    }

    deleteSection = (e, id) => {
        e.preventDefault()
        this.setState(prevState => {
            let index = prevState.sections.findIndex(section => section.id == id)
            return {
                sections: [
                    ...prevState.sections.slice(0, index),
                    ...prevState.sections.slice(index + 1)
                ]
            }
        })
    }

    changeSection = (e, id) => {
        let target = e.target
        if (target.type != 'checkbox')
            e.preventDefault()
        let name = target.name
        let value = target.type === 'checkbox' ? target.checked : target.type === 'select-multiple' ? Array.from(target.selectedOptions, option => option.value) : target.value
        this.setState(prevState => {
            let index = prevState.sections.findIndex(section => section.id == id)
            return {
                sections: [
                    ...prevState.sections.slice(0, index),
                    { ...prevState.sections[index], [name]: value },
                    ...prevState.sections.slice(index + 1)
                ]
            }
        })
    }

    changeSocial = (e) => {
        let target = e.target
        if (target.type != 'checkbox')
            e.preventDefault()
        let name = target.name
        let value = target.type === 'checkbox' ? target.checked : target.value
        if (name == "id" && value == "none")
            this.setState({ social: { id: "none", url: "", mic: false, sound: false, lang: '' } })
        else if (name == "sound" && !value)
            this.setState(prevState => ({ social: { ...prevState.social, mic: false, sound: false } }))
        else if (name == "mic" && value)
            this.setState(prevState => ({ social: { ...prevState.social, mic: true, sound: true } }))
        else
            this.setState(prevState => ({ social: { ...prevState.social, [name]: value } }))
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
                err.zob_err ? console.log('createteam - api.zob_err NOT HANDLE:' + err.zob_err + ' / ' + origin) : console.log('createteam - ERROR NOT FORMATED / ' + origin)
                console.log(err)
                break;
            }
        }
    }

    render() {
        let formOk = false
        //checkSession data
        if (this.props.userContext.logged && this.state.name && this.state.platform)
            formOk = true

        return <css.Container>
            <form onSubmit={this.submitForm}>
                <FieldTeamName
                    name={this.state.name}
                    handleChange={this.handleChange}
                />
                <FieldPrefix
                    prefix={this.state.prefix}
                    handleChange={this.handleChange}
                />
                <Filters.Langs
                    handleChange={this.handleChange}
                    lang={this.state.lang}
                />
                <Social
                    social={this.state.social}
                    url={this.state.social.url}
                    handleChange={this.changeSocial}
                />
                --- SECTIONS/GAME ---
                <br />
                <Filters.Platforms
                    platform={this.state.platform}
                    handleChange={this.handleChange}
                />
                <br />
                <Sections
                    sections={this.state.sections}
                    addSection={this.addSection}
                    changeSection={this.changeSection}
                    deleteSection={this.deleteSection}
                />
                <button type="submit" disabled={!formOk}>CREATE TEAM</button>
            </form>
        </css.Container>
    }
}

export default withAuth(CreateTeam)