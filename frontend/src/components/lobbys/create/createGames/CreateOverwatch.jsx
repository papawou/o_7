import React, { Component } from 'react';

import * as Filters from '../../../filters/zob'

const PartyType = ({ partyTypes, partyType, handleChange }) =>
    <div>
        partyType : <select name="partyType" value={partyType} onChange={handleChange}>
            <option value="">-- select a partyType --</option>
            {partyTypes.map(e => <option key={e} value={e}>{e}</option>)}
        </select>
    </div>


const Cv = ({ handleChange, handleRemove, handleCheck, roles, champions, cv, canDelete, is_owned }) =>
    <div>
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
        <button name="removePlayer" onClick={handleRemove} disabled={!canDelete}>DELETE CV</button>
        <input
            name="is_owned"
            type="checkbox"
            checked={is_owned}
            onChange={handleCheck}
        />
    </div>

const CvList = ({ cvs, handleCheck, setCv, deleteCv, roles, champions, cv_owner }) =>
    cvs.map((cv) =>
        <Cv
            cv={cv}
            roles={roles}
            champions={champions}
            is_owned={cv_owner == cv.id ? true : false}

            handleChange={(e) => { e.preventDefault(); setCv(cv.id, { config: { ...cv.config, [e.target.name]: e.target.value } }) }}
            handleCheck={(e) => { handleCheck(e.target.checked, cv.id) }}
            canDelete={cvs.length <= 2 ? false : true}
            handleRemove={(e) => { e.preventDefault(); deleteCv(cv.id) }}

            key={cv.id}
        />
    )

const SelectPartySize = ({ handleChange, partySize, maxPartySize }) => {
    const getOptions = () => {
        let options = []
        for (let i = 2; i <= maxPartySize; i++)
            options.push(<option value={i} key={i}>{i}</option>)
        return options
    }

    return <select name="partySize" value={partySize}
        onChange={handleChange}>
        {getOptions()}
    </select>
}

class CreateOverwatch extends Component {
    constructor(props) {
        super(props)
    }

    handlePartySize = (e) => {
        e.preventDefault()
        this.changePartySize(e.target.value)
    }

    handlePartyType = (e) => {
        e.preventDefault()
        this.changePartyType(e.target.value)
    }

    handleAddPlayer = (e) => {
        e.preventDefault()
        this.changePartySize(this.props.cvs.length + 1)
    }

    changePartySize = (size) => {
        if (size < this.props.cvs.length)
            this.props.deleteCvs(size)
        else if (size > this.props.cvs.length)
            this.props.addCvs(new Array(size - this.props.cvs.length).fill(this.props.datagame.default.cv))
    }

    changePartyType = (partyType) => {
        this.props.updateConfig({ partyType: partyType })
        let maxsize = this.props.datagame.partyType[partyType].maxPartySize
        if (maxsize < this.props.cvs.length)
            this.changePartySize(maxsize)
    }

    render() {
        return <div>
            <Filters.Platforms
                platforms={this.props.datagame.platforms}
                platform={this.props.platform}
                handleChange={this.props.updateState}
            />
            <PartyType
                partyType={this.props.config.partyType}
                handleChange={this.handlePartyType}
                partyTypes={this.props.datagame.partyTypes}
            />
            <SelectPartySize
                handleChange={this.handlePartySize}
                partySize={this.props.cvs.length}
                maxPartySize={this.props.datagame.partyType[this.props.config.partyType].maxPartySize}
                datagame={this.props.datagame}
            />
            <CvList
                cvs={this.props.cvs}
                cv_owner={this.props.cv_owner}

                roles={this.props.datagame.roles}
                champions={this.props.datagame.champions}

                setCv={this.props.setCv}
                deleteCv={this.props.deleteCv}
                handleCheck={this.props.handleCheck}
            />
            <button disabled={this.props.cvs.length == this.props.datagame.partyType[this.props.config.partyType].maxPartySize}
                onClick={this.handleAddPlayer}>
                Add player
            </button>
        </div>
    }
}

export default CreateOverwatch