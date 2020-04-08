import React from 'react'
import _io from '../utils/socketio'
//utils
import withAuth from './Auth'

const LobbyContext = React.createContext({
    _id: null,
    id_game: null,
    id_owner: null,
    members: [],
    name: null,
    size: 0,
    config: {},
    social: {},
    platform: null,
    cvs: [],

    joinLobby: () => { },
    createLobby: () => { },
    handleClick: () => { },
    io: null
})

class LobbyProvider_vanilla extends React.Component {
    constructor(props) {
        super(props)
        this.state = {
            _id: null,
            id_game: null,
            id_owner: null,
            members: [],
            name: null,
            size: 0,
            config: {},
            cvs: [],
            inited: false,

            joinLobby: this.joinLobby,
            createLobby: this.createLobby,
            handleClick: this.handleClick,

            io: _io.socket('/lobbys')
        }
    }
    componentDidMount() {
        this.onIo()
        if (this.props.userContext.inited) {
            if (this.props.userContext.logged)
                this.state.io.open()
            else
                this.setState({ inited: true })
        }
    }

    componentDidUpdate(prevProps, prevState) {
        if (this.props.userContext.inited) {
            if (prevProps.userContext.inited != this.props.userContext.inited && this.props.userContext.logged) { //fist once
                this.state.io.open()
            }
            else if (prevProps.userContext.logged != this.props.userContext.logged) {
                if (this.props.userContext.logged) {
                    //this.setState({inited:false})
                    this.state.io.open()
                }
                else
                    this.state.io.close()
            }
        }
    }

    componentWillUnmount() {
        this.offLobby()
        this.state.io.close()
    }

    joinLobby = (id_lobby) => {
        if (this.props.userContext.logged)
            this.state.io.emit('lobby:join', id_lobby, res => {
                try {
                    this.checkIoErr(res)
                    this.setState(res)
                }
                catch (err) {
                    console.log(err)
                }
            })
    }

    createLobby = async (data) => {
        if (this.props.userContext.logged) {
            return new Promise((resolve, reject) => {
                this.state.io.emit('lobby:create', data, res => {
                    try {
                        this.checkIoErr(res)
                        this.setState(res)
                        resolve(res._id)
                    }
                    catch (err) {
                        console.log(err)
                        reject(err)
                    }
                })
            })
        }
    }

    resetLobby = (id_lobby = null) => {
        this.setState({
            _id: id_lobby,
            id_game: null,
            id_owner: null,
            members: [],
            name: null,
            config: {},
            cvs: []
        })
    }

    onIo() {
        this.state.io.on('cv:join', this.ioJoinCv)
        this.state.io.on('cv:leave', this.ioLeaveCv)
        this.state.io.on('lobby:leave', this.ioLeaveLobby)
        this.state.io.on('lobby:join', this.ioJoinLobby)

        this.state.io.on('connect', () => {
            console.log(`/lobbys CONNECT`)
        })
        this.state.io.on('init', lobby => {
            this.setState(lobby)
            this.setState({ inited: true })
        })

        this.state.io.on('connect_error', (error) => {
            console.log('/lobbys CONNECT_ERROR')
            console.log(error)
        })

        this.state.io.on('error', (error) => {
            console.log('/lobbys ERROR')
            console.log(error)
        })

        this.state.io.on('disconnect', (reason) => {
            console.log(`/lobbys DISCONNECT - ${reason}`)
        })

        this.state.io.on('reconnect_attempt', () => {
            console.log(`/lobbys RECONNECT_ATTEMPT`)
        })

        this.state.io.on('reconnect', () => {
            console.log(`/lobbys RECONNECT`)
        })
    }

    offLobby = () => {
        this.state.io.off('cv:join', this.ioJoinCv)
        this.state.io.off('cv:leave', this.ioLeaveCv)
        this.state.io.off('lobby:leave', this.ioLeaveLobby)
        this.state.io.off('lobby:join', this.ioJoinLobby)
    }

    handleClick = (e, args) => {
        e.preventDefault()
        let name = e.target.name

        switch (name) {
            case 'joinCV': {
                let data = {
                    id_cv: args,
                    id_lobby: this.state._id
                }
                this.state.io.emit('cv:join', data, res => {
                    try {
                        this.checkIoErr(res)
                        this.setState(prevState => {
                            if (res.id_prevcv != null) {
                                let index = prevState.cvs.findIndex(cv => cv.id == res.id_prevcv)
                                prevState.cvs = this.changeCv(prevState, index, { id_owner: null })
                            }
                            let index = prevState.cvs.findIndex(cv => cv.id == res.id_newcv)
                            prevState.cvs = this.changeCv(prevState, index, { id_owner: this.props.userContext._id })
                            return prevState
                        })
                    }
                    catch (err) {
                        console.log(err)
                    }
                })
                break;
            }
            case 'leaveCV': {
                let data = {
                    id_lobby: this.state._id,
                    id_cv: args
                }

                this.state.io.emit('cv:leave', data, res => {
                    try {
                        this.checkIoErr(res)
                        this.setState(prevState => {
                            let index = prevState.cvs.findIndex(cv => cv.id == res.id_cv)
                            prevState.cvs = this.changeCv(prevState, index, { id_owner: null })
                            return prevState
                        })
                    }
                    catch (err) {
                        console.log(err)
                    }
                })
                break;
            }
            case 'exitLobby': {
                this.state.io.emit('lobby:leave')
                this.resetLobby()
                break;
            }
        }
    }

    ioJoinCv = data => {
        this.setState(prevState => {
            if (data.id_prevcv != null) {
                let index = prevState.cvs.findIndex(cv => cv.id == data.id_prevcv)
                prevState.cvs = this.changeCv(prevState, index, { id_owner: null })
            }
            let index = prevState.cvs.findIndex(cv => cv.id == data.id_newcv)
            prevState.cvs = this.changeCv(prevState, index, { id_owner: data.id_owner })
            return prevState
        })
    }
    ioLeaveCv = data => {
        this.setState(prevState => {
            let index = prevState.cvs.findIndex(cv => cv.id == data.id_cv)
            prevState.cvs = this.changeCv(prevState, index, { id_owner: null })
            return prevState
        })
    }
    ioLeaveLobby = data => {
        this.setState(prevState => {
            let index = prevState.cvs.findIndex(cv => cv.id_owner == data.id_user)
            if (index > -1)
                prevState.cvs = this.changeCv(prevState, index, { id_owner: null })
            index = prevState.members.findIndex(member => member._id == data.id_user)
            prevState.members.splice(index, 1)
            return prevState
        })
    }
    ioJoinLobby = member => {
        this.setState(prevState => {
            return prevState.members.push(member)
        })
    }

    checkIoErr = (data) => {
        if (data.zob_err)
            throw (data)
        else
            return
    }

    changeCv = (state, index, data) => [
        ...state.cvs.slice(0, index),
        { ...state.cvs[index], ...data },
        ...state.cvs.slice(index + 1)
    ]

    render() {
        return <LobbyContext.Provider value={this.state}>
            {
                this.props.children
            }
        </LobbyContext.Provider>
    }
}

export const LobbyProvider = withAuth(LobbyProvider_vanilla)

export default function withLobby(Component) {
    return (props) =>
        <LobbyContext.Consumer>
            {lobby => <Component {...props} lobbyContext={lobby} />}
        </LobbyContext.Consumer>
}