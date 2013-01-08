# This reads the configuration file.
#
# All of the application configuration is stored in a config.yaml file
# in the present directory or it walks up the directories until it
# finds the config.yaml.
#
# This also looks for the ENVIRONMENT variable 'NODE_YAML_CONFIG' and
# if set uses that file instead. This enables the configuration to be
# placed into a directory that isn't 'deployed' and thus can be
# consistent across upgrades.
#
#
# The configuration document is:
#
# production: or development: or testing:
#
# followed by: (indented)
#
# central-server:
#   session:
#     database:
#       db: 'db'
#       host: 'localhost'
#       collection: 'sessions' # default
#     secret: '90dzZXs2AxdCzTB5'
#     key: 'uhq_session'
#   account:
#     url: /account
#   etc.
#
# The 'central-server' bit allows the same yaml config file to work
# for lots of servers!

require 'js-yaml'
fs = require 'fs'

# the filename to find
FIND_NAME = 'config.yaml'

# where we store the config after we've required it.
Loaded_config = null
Processed_config = null

# work out what environment we are running in
environment_name = () ->
  if process.env.TESTING or process.env.NODE_TESTING then return 'testing'
  if process.env.PRODUCTION then return 'production'
  return 'development'


# first find the filename
find_config_file = () ->
  if process.env.NODE_YAML_CONFIG
    yaml_filename = process.env.NODE_YAML_CONFIG
    try
      stats = fs.statSync yaml_filename
      if not stats.isFile()
        throw new Error("No dice I'm afraid!")
    catch error
      console.log "No configuration file at " + yaml_filename
      process.exit(1)
  else
    directory = __dirname
    finished = false
    until finished
      yaml_filename = directory + '/' + FIND_NAME
      try
        stats = fs.statSync yaml_filename
        if stats.isFile()
          break
      if directory is '/'
        console.log "FATAL! -- Couldn't file '#{FIND_NAME}' recursively" +
                    " to '/' from '#{__dirname}'"
        process.exit(1)
      directory = fs.realpathSync(directory + '/..')
  return yaml_filename


# recurse a set of 'given' assoc array and the 'def' default array and
# copy into the result array (which is returned).  i.e. result is def,
# overriden by given.
recurse_doc = (given, def) ->
  result = {}

  # first check if we have everything in the default 'def' array
  for k, v of def
    #console.log "---"
    #console.log "Key: " + k
    #console.log "Value: " + v
    unless k of given
      result[k] = v
    else
      if typeof(def[k]) is 'object'
        if typeof(given[k]) != 'object'
          console.log "FATAL! -- key #{k} is not an object in provided config file"
          process.exit(1)
        result[k] = recurse_doc given[k], def[k]
      else
        result[k] = given[k]
  # also copy over any keys in 'given' that aren't in the defaults
  for k, v of given
    unless k of def
      result[k] = v
  return result


# read the config file and return it
read_config_file = (filename, environment) ->
  if Loaded_config is null
    #console.log "Using config from #{filename}"
    Loaded_config = config_doc = require(filename).shift()
  else
    config_doc = Loaded_config
  # firstly, make sure that we are reading the right part of the file according to the environment
  environment or= environment_name()
  if environment of config_doc and (typeof config_doc[environment] is 'object')
    config_doc = config_doc[environment]
    # check that 'central-server' is in the document and is an
    # object. It's the only bit that we want
    return config_doc
  else
    console.log "FATAL! -- #{environment} doesn't appear in the yaml file provided:"
  console.log filename
  process.exit(1)


# process the config - if we've been supplied with an object, then use it, otherwise try to read
# the file
process_config = (config_obj, environment) ->
  # if we are testing then we need to use the configured object.
  if config_obj?
    #console.log "Using a test configuration object"
    # clone to avoid any messing with the object passed in after the fact
    Processed_config = _clone config_obj
    return Processed_config
  # if we've already processed the config this just return it.
  if Processed_config?
    # console.log "Just returning a previously processed configuration"
    return Processed_config
  # find the config file and then read it into config.
  config_filename = find_config_file()
  #console.log config
  return read_config_file config_filename, environment


# deep clone an object and return a copy which shares no references.
# from: http://coffeescriptcookbook.com/chapters/classes_and_objects/cloning
_clone = (obj) ->
  if not obj? or typeof obj isnt 'object'
    return obj
  if obj instanceof Date
    return new Date(obj.getTime()) 
  if obj instanceof RegExp
    flags = ''
    flags += 'g' if obj.global?
    flags += 'i' if obj.ignoreCase?
    flags += 'm' if obj.multiline?
    flags += 'y' if obj.sticky?
    return new RegExp(obj.source, flags) 
  newInstance = new obj.constructor()
  for key of obj
    newInstance[key] = _clone obj[key]
  return newInstance

# finally, make the modules be the config object so we can use it directly
module.exports = process_config
