import React from 'react'
import withAuth from '../../../../contexts/Auth';
import queryString from 'query-string'
import Request from './Request'
import { Link } from 'react-router-dom'
const ListRequest = ({ request }) =>
    <li>
        <Link to={`?id=${request._id}`}>{request._id}</Link>
    </li>

const ListRequests = ({ requests }) =>
    <ul>
        {requests.map(request => <ListRequest key={request._id} request={request} />)}
    </ul>

class Requests extends React.Component {
    constructor(props) {
        super(props)
        this.state = {
            requests: []
        }
    }

    componentDidMount() {
        this.props.userContext.authfetch('event/get', { id: this.props.match.params.id_event, fields: ['requests'] })
            .then(requests => {
                console.log(requests)
                this.setState(requests)
            })
            .catch(err => console.log(err))
    }

    componentDidUpdate(prevProps) {
        if (this.props.match.params.id_event != prevProps.match.params.id_event) {
            //reset State?
            this.props.userContext.authfetch('event/get', { id: this.props.match.params.id_event, fields: ['requests'] })
                .then(requests => {
                    console.log(requests)
                    this.setState(requests)
                })
                .catch(err => console.log(err))
        }
    }

    render() {
        let queries = queryString.parse(this.props.location.search)
        let id_event = this.props.match.params.id_event
        return <div>
            REQUESTS ( {this.state.requests.length} ) - {id_event}
            {
                queries.id ?
                    <Request id={queries.id} id_event={id_event} /> :
                    <ListRequests requests={this.state.requests} />
            }
        </div>
    }
}

export default withAuth(Requests)