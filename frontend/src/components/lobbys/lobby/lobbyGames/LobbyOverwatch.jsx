import React, { Component } from 'react'
import { Link } from 'react-router-dom'
const Cv = ({ role, champion, owner, id_owner, id_user, handleClick }) =>
    <ul>
        <li>{role}</li>
        <li>{champion}</li>
        <li>{owner ? <Link to={`/user/${owner._id}`}>{owner.name}</Link> : "FREE"}</li>
        <button name={owner ? 'leaveCV' : 'joinCV'} disabled={owner && id_owner != id_user} onClick={handleClick}>{id_user == id_owner ? 'LEAVE' : 'JOIN'}</button>
    </ul>


const CvsList = ({ cvs, members, id_user, handleClick }) =>
    <div>
        {cvs.map(cv => <Cv key={cv.id} id_user={id_user} handleClick={(e) => handleClick(e, cv.id)} role={cv.config.role} champion={cv.config.champion} id_owner={cv.id_owner ? cv.id_owner : null} owner={members.find(member => member._id == cv.id_owner)} />)}
    </div>


class LobbyOverwatch extends Component {
    constructor(props) {
        super(props)
    }

    render() {
        console.log(this.props.members)
        return <div>
            LobbyOverwatch
            <CvsList
                cvs={this.props.cvs}
                members={this.props.members}
                id_user={this.props.id_user}
                handleClick={this.props.handleClick}
            />
        </div>
    }
}

export default LobbyOverwatch