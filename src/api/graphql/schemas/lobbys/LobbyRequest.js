import { User } from "../users/User"
import { Lobby } from "./Lobby"
import { LobbyUserInterface } from './LobbyUser'

export const schema = `
enum LobbyRequestStatus {
	WAITING_USER
	WAITING_CONFIRM_LOBBY
	WAITING_LOBBY
	DENIED_BY_LOBBY
	DENIED_BY_USER
}

type LobbyRequest implements LobbyUserInterface {
  id: ID!
  user: User!
	lobby: Lobby!
	
	status: LobbyRequestStatus!
	created_by: User
}
`
export const resolvers = {
}

export class LobbyRequest extends LobbyUserInterface {
	constructor(lobbyrequest) {
		super(lobbyrequest)
		this.status = lobbyrequest.status

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
		let lobbyrequest = await super.gen(ctx, id_lobby, id_user)
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