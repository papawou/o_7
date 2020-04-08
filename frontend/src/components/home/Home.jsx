import React, { Component } from 'react';
//utils
import { Link } from 'react-router-dom'
//css
import * as css from './css/Home'

class Home extends Component {
	constructor(props) {
		super(props)
	}

	render() {
		return <css.Container>
			<css.Category>
				<css.Option>
					Create your filtered lobby where others players can join
					<Link to="/lobby/create">
						<button type="button">CREATE LOBBY</button>
					</Link>
				</css.Option>
				<css.Option>
					Meet others players, they want what you want !
					<Link to={`/lobby/search`}>
						<button type="button">SEARCH LOBBYS</button>
					</Link>
				</css.Option>
			</css.Category>
			<css.Category>
				<css.Option>
					Create a team, manage and clash others teams !
					<Link to={`/team/create`}>
						<button type="button">CREATE TEAM</button>
					</Link>
				</css.Option>
				<css.Option>
					Seek for e-sport team or just for fun ?
					<Link to={`/team/search`}>
						<button type="button">SEARCH TEAMS</button>
					</Link>
				</css.Option>
			</css.Category>
			<css.Category>
				<css.Option>
					Create an event for public, e-sport, social !
					<Link to={`/event/create`}>
						<button type="button">CREATE EVENT</button>
					</Link>
				</css.Option>
				<css.Option>
					Want participate an event ? Like e-sport, or roleplay event. Welcome to video games !
					<Link to={`/event/search`}>
						<button type="button">SEARCH EVENTS</button>
					</Link>
				</css.Option>
			</css.Category>
		</css.Container>
	}
}

export default Home;