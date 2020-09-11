import { User } from "../users/User"
import { Lobby } from "./Lobby"
import { LobbyUserInterface } from "./LobbyUser"

export const schema = `
type LobbyBan {
	id: ID!
	user: User!
	lobby: Lobby!
		
	ban_resolved_at: String
}
`

export class LobbyBan extends LobbyUserInterface {
	constructor(lobbyban) {
		super(lobbyban)
		this.ban_resolved_at = lobbyban.resolved_at

		this.id = LobbyBan.encode(lobbyban.id_lobby, lobbyban.id_user)
	}
	static __typename = 'LobbyBan'

	//field
	async user(args, ctx) {
		return await User.gen(ctx, this._id_user)
	}
	async lobby(args, ctx) {
		return await Lobby.gen(ctx, this._id_lobby)
	}

	//fetch
	static async gen(ctx, id_lobby, id_user) {
		let lobbyban = await super.gen(ctx, id_lobby, id_user)
		return lobbyban.ban_resolved_at ? new LobbyBan(lobbyban) : null
	}

	//utils
	static encode(id_lobby, id_user) {
		return LobbyBan.__typename + '_' + id_lobby + '-' + id_user
	}

	static decode(cid_lobby) {
		return cid_lobby.slice(LobbyBan.__typename.length + 1).split('-')
	}
}