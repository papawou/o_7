import React, { Component } from 'react'

import * as Filters from '../../../filters/zob'

const Cv = ({ cv, handleChange, roles, champions }) =>
    <div>
        role : <select name="role" onChange={handleChange} value={cv.role}>
            <option value="">-- select a role --</option>
            {roles.map(role => <option value={role} key={role}>{role}</option>)}
        </select>
        champion : <select name="champion" onChange={handleChange} value={cv.champion}>
            <option value="">-- select a champion --</option>
            {champions.map(champion => <option value={champion} key={champion}>{champion}</option>)}
        </select>
    </div>

const PartyType = ({ partyTypes, partyType, handleChange }) =>
    <div>
        partyType : <select name="partyType" value={partyType} onChange={handleChange}>
            <option value="">-- select a partyType --</option>
            {partyTypes.map(e => <option key={e} value={e}>{e}</option>)}
        </select>
    </div>

class SearchOverwatch extends Component {
    constructor(props) {
        super(props)
    }

    handleConfig = (e) => {
        e.preventDefault()
        this.props.updateConfig({ [e.target.name]: e.target.value })
    }

    handleCV = (e) => {
        e.preventDefault()
        this.props.updateCv({ config: { ...this.props.cv, [e.target.name]: e.target.value } })
    }

    render() {
        return <div>
            <Filters.Platforms
                platforms={this.props.datagame.platforms}
                platform={this.props.platform}
                handleChange={this.props.updateState}
            />
            <br />
            <PartyType
                partyType={this.props.config.partyType}
                handleChange={this.handleConfig}
                partyTypes={this.props.datagame.partyTypes}
            />
            <Cv
                cv={this.props.cv}
                handleChange={this.handleCV}
                champions={this.props.datagame.champions}
                roles={this.props.datagame.roles}
            />
        </div>
    }
}

export default SearchOverwatch