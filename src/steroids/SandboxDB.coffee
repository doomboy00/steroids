util = require "util"
fs = require "fs"

restify = require "restify"
yaml = require 'js-yaml'

paths = require "./paths"
Login = require "./Login"
dataHelpers = require "./dataHelpers"

configurationFilePath = 'config/sandboxdb.yaml'

sandboxDBBaseURL = 'https://datastorage-api.appgyver.com'
sandboxDBURL = "#{sandboxDBBaseURL}/v1/datastorage"

class SandboxDB
  @SandboxDBError: class SandboxDBError extends steroidsCli.SteroidsError
  @ProvisionError: class ProvisionError extends SandboxDBError
  @WriteFileError: class WriteFileError extends SandboxDBError

  providerName: "appgyver_sandbox"
  providerTypeId: 6

  constructor: (@options={}) ->
    @apiClient = restify.createJsonClient
      url: sandboxDBBaseURL
    @apiClient.basicAuth Login.currentAccessToken(), 'X'

  get: =>
    return new Promise (resolve, reject) =>
      steroidsCli.debug "SANDBOXDB", "Initializing Sandbox DB"

      @readFromFile().then =>
        if @existsSync() #TODO: cannot be called before @readFromFile is resolved
          steroidsCli.debug "SANDBOXDB", "Sandbox DB already created"
          resolve()
        else
          steroidsCli.debug "SANDBOXDB", "Sandbox DB not created, creating a new one."
          @create().then resolve

  create: =>
    return new Promise (resolve, reject) =>
      steroidsCli.debug "SANDBOXDB", "Creating Sandbox DB"

      @provision()
      .then(@writeToFile)
      .then(resolve)

  provision: =>
    return new Promise (resolve, reject) =>
      steroidsCli.debug "SANDBOXDB", "Provisioning Sandbox DB"

      data =
        appId: dataHelpers.getAppId()

      steroidsCli.debug "SANDBOXDB", "POSTing data: #{JSON.stringify(data)} to path: /v1/credentials/provision"
      @apiClient.post '/v1/credentials/provision', { data: data }, (err, req, res, obj) =>
        if obj.code == 201 #TODO: betterify this line
          steroidsCli.debug "SANDBOXDB", "Provisioning Sandbox DB returned success: #{JSON.stringify(obj)}"
          @fromApiSchemaDict(obj.body)
          resolve()
        else
          steroidsCli.debug "SANDBOXDB", "Provisioning Sandbox DB returned failure: #{JSON.stringify(obj)}"
          reject new ProvisionError err

  writeToFile: =>
    return new Promise (resolve, reject) =>
      steroidsCli.debug "SANDBOXDB", "Writing configuration to file #{configurationFilePath}"
      steroidsCli.debug "SANDBOXDB", "Writing configuration: #{JSON.stringify(@toConfigurationDict())}"

      dataHelpers.overwriteYamlConfig(configurationFilePath, @toConfigurationDict())
      .then =>
        steroidsCli.debug "SANDBOXDB", "Writing configuration to file #{configurationFilePath} was success"
        resolve()
      .fail (err)=>
        steroidsCli.debug "SANDBOXDB", "Writing configuration to file #{configurationFilePath} was failure", err
        reject new WriteFileError err

  readFromFile: =>
    return new Promise (resolve, reject) =>
      steroidsCli.debug "SANDBOXDB", "Reading configuration from file #{configurationFilePath}"

      unless fs.existsSync(configurationFilePath)
        steroidsCli.debug "SANDBOXDB", "Configuration file #{configurationFilePath} was missing"
        resolve()
        return

      @fromConfigurationDict yaml.safeLoad(fs.readFileSync(configurationFilePath, 'utf8'))

      resolve()

  configurationKeysForProxy: =>
    bucket_id: @id
    steroids_api_key: @apikey
    bucket_name: @name

  # legacy yaml format abstracted here
  toConfigurationDict: =>
    apikey: @apikey
    bucket: @name
    bucket_id: @id

  # legacy yaml format abstracted here
  fromConfigurationDict: (obj)=>
    @apikey = obj.apikey
    @name = obj.bucket
    @id = obj.bucket_id

  # datastore api schema abstracted here
  fromApiSchemaDict: (obj)=>
    @apikey = "#{obj.login}#{obj.password}"
    @name = obj.name
    @id = obj.datastore_bucket_id

  existsSync: -> #TODO: make async
    return @id?

module.exports = SandboxDB
