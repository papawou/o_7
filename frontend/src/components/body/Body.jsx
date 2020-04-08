import React from 'react'
//utils
import { Link, Route, Switch } from 'react-router-dom'
//components
import Home from '../home/Home'
//LOBBYS
import SearchLobby from '../lobbys/search/SearchLobby'
import CreateLobby from '../lobbys/create/CreateLobby'
import Lobby from '../lobbys/lobby/Lobby'
//TEAMS
import SearchTeam from '../teams/search/SearchTeam'
import CreateTeam from '../teams/create/CreateTeam'
import Team from '../teams/team/Team'
//TEAMS - SECTIONS
import Section from '../teams/section/Section'
//EVENTS
import SearchEvent from '../events/search/SearchEvent'
import CreateEvent from '../events/create/CreateEvent'
import Event from '../events/event/Event'
//...
import User from '../users/User'
import Register from '../users/Register'

/*
	handle path="/:id" with /00/others
	<Component key={:id} /> for force update
*/

const Error_Found = (props) => (
	<div>
		ERROR 404: {props.location.pathname}<br />
		<Link to='/'>GO BACK HOME</Link>
	</div>
)

const R_User = () => (
	<Switch>
		<Route exact path="/user/:id_user" component={(props) => <User {...props} />} />
		<Route component={Error_Found} />
	</Switch>
)

const R_Lobby = () => (
	<Switch>
		<Route exact path="/lobby/create" component={CreateLobby} />
		<Route exact path="/lobby/search" component={SearchLobby} />
		<Route exact path="/lobby/:id_lobby" component={(props) => <Lobby {...props} />} />
		<Route component={Error_Found} />
	</Switch>
)

const R_Team = () => (
	<Switch>
		<Route exact path="/team/create" component={CreateTeam} />
		<Route exact path="/team/search" component={SearchTeam} />
		<Route exact path="/team/:id_team" component={(props) => <Team {...props} />} />
		<Route component={Error_Found} />
	</Switch>
)

const R_Event = () => (
	<Switch>
		<Route exact path="/event/create" component={CreateEvent} />
		<Route exact path="/event/search" component={SearchEvent} />
		<Route path="/event/:id_event" component={Event} />
		<Route component={Error_Found} />
	</Switch>
)

const Body = () => (
	<Switch>
		<Route exact path="/" component={Home} />
		<Route exact path="/register" component={Register} />
		<Route path="/lobby" component={R_Lobby} />
		<Route path="/team" component={R_Team} />
		<Route path="/user" component={R_User} />
		<Route path="/event" component={R_Event} />
		<Route exact path="/section/:id_section" component={Section} />
		<Route component={Error_Found} />
	</Switch>
)

export default Body;