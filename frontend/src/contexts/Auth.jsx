import React from 'react'
import Cookies from 'js-cookie'
import _io from '../utils/socketio'
//utils
import * as _api from '../utils/api'

export const UserContext = React.createContext({
    id: "",
    name: "",

    logged: false,

    login: () => { },
    logout: () => { },
    authfetch: () => { },
    openIo: () => { },
    closeIo: () => { },
    inited: false,
    io: null
})

export class UserProvider extends React.Component {
    constructor(props) {
        super(props)

        this.state = {
            id: "",
            name: "",

            logged: false,

            login: this.login,
            logout: this.logout,
            authfetch: this.authfetch,

            inited: false,
            io: _io.socket('/'),

            //Test
            openIo: this.openIo,
            closeIo: this.closeIo
        }
    }

    componentDidMount() {
        this.onIo()
        if (Cookies.get('zobId')) {
            console.log('GOT COOKIE')
            _api.afetch('user/log')
                .then(res => {
                    this.state.io.open()
                    this.setState({ ...res, logged: true, inited: true })
                })
                .catch(err => {
                    console.log(err)
                    this.state.io.open()
                    this.setState({ inited: true })
                })
        }
        else {
            console.log('NO COOKIE')
            this.state.io.open()
            this.setState({ inited: true })
        }
    }

    login = async (name, password) => {
        _io.close()
        _api.afetch('user/login', { name: name, password: password })
            .then(user => {
                this.setState({ ...user, logged: true })
            })
            .catch(err => {
                console.log('prout')
                console.log(err)
            })
    }

    logout = () => {
        _io.close()
        _api.afetch('user/logout')
            .then(res => {
                let guest = { id: "", name: "" }
                this.setState({ ...guest, logged: false })
            })
            .catch(err => {
                let guest = { id: "", name: "" }
                this.setState({ ...guest, logged: false })
            })
    }

    componentDidUpdate(prevProps, prevState) {
        if (prevState.logged != this.state.logged) {
            _io.open()
        }
    }

    refreshIo() {
        _io.close()
        _io.open()
    }
    onIo() {
        this.state.io.on('connect', () => {
            console.log(`SOCKET io CONNECT`)
        })

        this.state.io.on('disconnect', (reason) => {
            console.log(`SOCKET io DISCONNECT - ${reason}`)
        })

        this.state.io.on('reconnect_attempt', () => {
            console.log(`SOCKET io RECONNECT_ATTEMPT`)
        })

        this.state.io.on('reconnect', () => {
            console.log(`SOCKET io RECONNECT`)
        })
    }
    openIo = () => {
        this.state.io.open()
        console.log(this.state.io)
    }
    closeIo = () => {
        this.state.io.close()
        console.log(this.state.io)
    }
    openManager = () => {
        _io.open()
    }
    closeManager = () => {
        _io.close()
    }

    authfetch = async (url, data = {}) => {
        if (this.state.logged) {
            try {
                let res = await _api.afetch(url, data)
                return res
            }
            catch (err) {
                this.handleCustomError(err, 'authfetch')
                if (err == 401)
                    this.logout()
                else
                    throw (err)
            }
        }
        else {
            throw ('authfetch called but unlogged')
        }
    }

    handleCustomError = (err, origin = false) => {
        switch (err.zob_err) {
            default: {
                err.zob_err ? console.log('context.Auth - zob_err NOT HANDLE:' + err.zob_err + ' / ' + origin) : console.log('context.Auth - ERROR NOT FORMATED / ' + origin)
                console.log(err)
                break;
            }
        }
    }

    render() {
        return <UserContext.Provider value={this.state}>
            {
                this.props.children
            }
        </UserContext.Provider>
    }
}

export default function withAuth(Component) {
    return (props) =>
        <UserContext.Consumer>
            {context => context.inited ?
                <Component {...props} userContext={context} /> :
                <UserLoading />
            }
        </UserContext.Consumer>
}

const UserLoading = (props) =>
    <div>
        USER_PROVIDER LOADING...
    </div>

