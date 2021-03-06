"use strict"
_ = require('./underscore')

isDebug = false

# ===============================================================================
class Command
  constructor: (@config, @parent) ->

  execute: (a , b) ->
    this.parameters = arguments
    if @config.execute then @config.execute.apply(@, arguments)

  undo: () ->
    if @config.undo then @config.undo.apply(@, this.parameters)

  translate: () ->
    if @config.translate then @config.translate.apply(@, this.parameters)

  next: (cmd) ->
    old = @nextCMD
    newCommand = new Command
    @nextCMD = new CommandStream(c, @parent, config)
    @nextCMD.predecessor = @

    if old?
      @nextCMD.nextCMD = old
      old.predecessor = @nextCMD

    return @nextCMD

#class 

# ===============================================================================
class CommandStream
  constructor: (@cmd, @parent, @config, @environment) ->
    @cmdRoutine = []
    @active = true

  getEnvironment: () ->
    return @environment if @environment?
    return @parent.getEnvironment() if @parent?
    return @predecessor.getEnvironment() if @predecessor?

  getCallback: (id) ->
    try
      return @config[id].callback if @config?
      return @parent.getCallback(id) if @parent?
      return @predecessor.getCallback(id) if @predecessor?
    catch error
      console.log('Failed to get', id, 'from',  @config)
      return null

  getOutput: (id) ->
    return @config[id].output if @config? and id?
    return @parent.getOutput(id) if @parent?
    return @predecessor.getOutput(id) if @predecessor?
    return null
  
  process: () ->
    if @active and @getCallback(@cmd.id)?
      console.log('Processing:', @cmd.id) if isDebug
      @getEnvironment().setVariableField(@cmd) if @getEnvironment()?
      @getCallback(@cmd.id).apply(@, [@getEnvironment()])

    routine.process() for routine in @cmdRoutine
    @nextCMD.process() if @nextCMD
  
  print: (placeHolder = '') ->
    console.log(placeHolder + @cmd.id)
    r.print(placeHolder+'  ') for r in @cmdRoutine
    @nextCMD.print(placeHolder+'>') if @nextCMD?

  output: () ->
    ret = []
    if @active and @getOutput(@cmd.id)?
      @getEnvironment().setVariableField(@cmd) if @getEnvironment()?
      ret = @getOutput(@cmd.id).apply(@, [@getEnvironment()])

    return ret

  routine: (c, config) ->
    r = new CommandStream(c, @, config)
    @cmdRoutine.push(r)
    return r

  suicide: () ->
    @active = false

  getPrevCommand: (id) ->
    return null unless @parent
    return @parent if @parent.cmd.id is id
    return @parent.getPrevCommand(id)

  next: (c, config) ->
    old = @nextCMD
    @nextCMD = new CommandStream(c, @parent, config)
    @nextCMD.predecessor = @

    if old?
      @nextCMD.nextCMD = old
      old.predecessor = @nextCMD

    return @nextCMD

  translate: () -> @getEnvironment().translate(@)

class Environment
  constructor: () ->

  setVariableField: (@VariableField) ->

  variable: (key, val) ->
    return @VariableField unless key?
    @VariableField[key] = val if val?
    return @VariableField[key]

  rand: () -> return Math.random()

  randMember: (array, count = 1) ->
    return [] unless Array.isArray(array)
    return [] unless array.length >= count
    return array if array.length is count and count isnt 1
    indexes = [0..array.length-1]
    result = (array[Math.floor(indexes.splice(@rand() * indexes.length, 1)[0])] for i in [1..count])
    result = result[0] if count is 1

    return result

  chanceCheck: (chance) -> @rand() < chance

# ===============================================================================
command_config = {
  modify_property: {
    description: '修改属性',
    parameters: {
        property: '属性对象'
    },
    execute: (parameter) ->
      obj = parameter.obj
      @backup = {}
      for key, p of parameter.property
        @backup[key] = obj[key]
        obj[key] = p

    undo: (parameter) ->
      obj = parameter.obj
      for k, p of @backup
        if p?
          obj[k] = p
        else
          delete obj[k]

    translate: (obj) ->
      return JSON.stringify(obj)
  },
  incress_property: {
    execute: (parameter) ->
      originProperty = _(parameter.obj).pick(_(parameter.property).keys())
      for k, v of parameter.property
        if originProperty[k] then v = originProperty[k] + v
        originProperty[k] = v

      @cmd_modifyProperty = makeCommand('modify_property')
      @cmd_modifyProperty.execute({obj: parameter.obj, property:originProperty})

    undo: () -> @cmd_modifyProperty.undo()
  }
}

makeCommand = (name) -> return new Command(command_config[name])
extention = {
  interfaces: {
    makeCommand: (commandName) ->
      return null unless @getCommandConfig(commandName)
      return new Command(@getCommandConfig(commandName))

    executeCommand: (commandName, parameter) ->
      if _(commandName).isArray()
        for k, cmd of commandName
          @executeCommand(cmd.type, cmd)
      else
        command = @makeCommand(commandName)
        throw new Error('Command('+commandName+') is not supported.', commandName) unless command
        localParameter = _({ obj: this}).extend(parameter)
        command.execute(localParameter)

    getCommandConfig: (commandName) ->
      return @command_config[commandName]
  }
}
isRequirementMatched = (obj, config) ->
  return true unless config
  obj = obj.prototype
  return config.reduce(((r, l) -> return r and typeof obj[l.field] is l.type), true)

installExtention = (obj, config) ->
  throw new Error('Install extention failed') unless isRequirementMatched(obj, config.requirement)
  for field, value of config.interfaces
    continue if obj.prototype[field]
    obj.prototype[field] = value
# ===============================================================================
exports.CommandStream = CommandStream
exports.Environment = Environment
exports.Command = Command
exports.makeCommand = makeCommand
exports.command_config = command_config
exports.installCommandExtention = (obj) -> installExtention(obj, extention)

exports.fileVersion = -1
