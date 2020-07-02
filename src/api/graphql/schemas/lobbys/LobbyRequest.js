import { User } from "../users/User"
import { Lobby } from "./Lobby"
import * as LobbyUserInterface from './LobbyUser'

export const schema = `
enum LobbyRequestStatus {
	WAITING_USER
	WAITING_CONFIRM_LOBBY
	WAITING_LOBBY
	DENIED_BY_LOBBY
	DENIED_BY_USER
}

interface LobbyRequestInterface {
  id: ID!
  user: User!
	lobby: Lobby!
	
	status: LobbyRequestStatus!
}

type LobbyRequest implements LobbyRequestInterface {
  id: ID!
  user: User!
	lobby: Lobby!
	
	status: LobbyRequestStatus!
	created_by: User
}
`
export const resolvers = {
}

export class LobbyRequest {
	constructor(lobbyrequest) {
		this._id_lobby = lobbyrequest.id_lobby
		this._id_user = lobbyrequest.id_user

		this.id = LobbyRequest.encode(lobbyrequest.id_lobby, lobbyrequest.id_user)
	}
	static __typename = 'LobbyRequest'

	//field
	async user(args, ctx) {
		return await User.gen(ctx, this._id_user)
	}
	async lobby(args, ctx) {
		return await Lobby.gen(ctx, this._id_lobby)
	}

	//fetch
	static async gen(ctx, id_lobby, id_user) {
		let lobbyrequest = await LobbyUserInterface.gen(ctx, id_lobby, id_user)
		return lobbyrequest.status ? new LobbyRequest(lobbyrequest) : null
	}

	//utils
	static encode(id_lobby, id_user) {
		return LobbyRequest.__typename + '_' + id_lobby + '-' + id_user
	}

	static decode(cid) {
		return cid.slice(LobbyRequest.__typename.length + 1).split('-')
	}
}