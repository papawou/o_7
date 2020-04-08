import React from 'react';
import { Link } from 'react-router-dom'
//COMPONENTS
import Account from './Account'
//utils
import * as api from '../../utils/api'
//CSS
import * as css from './css/Header'

let timeout = null;
class Header extends React.Component {
    constructor(props) {
        super(props)
        this.state = {
            searchInput: ""
        }
    }

    handleChange = (e) => {
        e.preventDefault()
        let target = e.target
        let name = target.name
        let value = target.type === 'checkbox' ? target.checked : target.type === 'select-multiple' ? Array.from(target.selectedOptions, option => option.value) : target.value

        this.setState({ [name]: value })
    }

    handleSearch = (e) => {
        e.preventDefault()
        let target = e.target
        let name = target.name
        let value = target.value

        this.setState({ [name]: value })
    }

    componentDidUpdate = (prevProps) => {
        let searchInput = this.state.searchInput
        if (prevProps.searchInput != searchInput && searchInput.length != 0) {
            if (timeout)
                clearTimeout(timeout)
            timeout = setTimeout(this.searchFetch, 500)
        }
    }

    searchFetch = () => {
        let data = { data: this.state.searchInput }
        api.afetch('search/game', data)
            .then(res => console.log(res))
            .catch(err => this.handleCustomError(err, 'searchFetch'))
    }

    handleCustomError = (err, origin = false) => {
        switch (err.err) {
            default: {
                err.err ? console.log('header - api.err NOT HANDLE:' + err.err + ' / ' + origin) : console.log('header - ERROR NOT FORMATED / ' + origin)
                console.log(err)
                break;
            }
        }
    }

    render() {
        return <css.Container>
            <Link to='/'><button>HOME</button></Link>
            <Link to='/graphql'><button>GRAPHQL</button></Link>
            {/*<input name="searchInput" placeholder="Search..." onChange={this.handleSearch} type="text" value={this.state.searchInput} />*/}
            <Account />
        </css.Container>
    }
}

export default Header;