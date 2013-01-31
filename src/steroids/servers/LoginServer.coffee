Server = require "../Server"
Converter = require "../Converter"
util = require "util"

fs = require "fs"
Paths = require "../paths"

class LoginServer extends Server
  setRoutes: =>
    @app.get "/callback", (req, res) =>
      if req.query.code && req.query.response_type == "code"
        @options.loginHandler.consumeAuthorizationCode(req.query.code)

        res.redirect '/success'
      else
        res.status(500).send "FAIL"

    @app.get "/success", (req, res) =>
      res.status(200).sendfile(Paths.oauthSuccessHTML)


module.exports = LoginServer
