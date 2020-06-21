import db from '../postgresql/client'
import sql from '../postgresql/sql/root'
import initLoaders from '../dataloader/root'
import { Viewer } from './schemas/users/Viewer'
import Loaders from '../dataloader/root'
import { redis } from '../redis/client'

export class Context {
    constructor(request, response, viewer) {
        this.res = response
        this.req = request
        this.viewer = viewer
        this.db = db
        this.sql = sql
        this.dl = initLoaders(this)
        //this.dl = new Loaders(this)
        this.redis = redis
    }

    static gen(req, res) {
        let viewer = req.session._id ? Viewer.gen(req.session._id) : null
        return new Context(req, res, viewer)
    }
}