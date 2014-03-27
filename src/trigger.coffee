doGetProperty = (obj, key) ->
  properties = key.split('.')
  for k in properties
    if obj? then obj = obj[k] else return undefined
  return obj

exports.doGetProperty = doGetProperty

conditionCheck = (conditionFormular, variables, cmd) ->
  return false unless getTypeof(conditionFormular) is 'Boolean'
  return true if conditionFormular is true
  return false if conditionFormular is false
  for k, c of conditionFormular
    switch k
      when '>'
        return parse(c[0], variables, cmd) >  parse(c[1], variables, cmd)
      when '<'
        return parse(c[0], variables, cmd) <  parse(c[1], variables, cmd)
      when '=='
        return parse(c[0], variables, cmd) == parse(c[1], variables, cmd)
      when '!='
        return parse(c[0], variables, cmd) != parse(c[1], variables, cmd)
      when '<='
        return parse(c[0], variables, cmd) <= parse(c[1], variables, cmd)
      when '>='
        return parse(c[0], variables, cmd) >= parse(c[1], variables, cmd)
      when 'or'
        return parse(c, variables, cmd).some( (x) -> parse(x, variables, cmd) )
      when 'and'
        return parse(c, variables, cmd).every( (x) -> parse(x, variables, cmd) )
      when 'not'
        return not parse(c, variables, cmd)

exports.conditionCheck = conditionCheck
parse = (expr, variable, cmd) ->
  if Array.isArray(expr)
    return expr.map( (e) -> parse(e, variable, cmd) )
  else
    switch getTypeof(expr)
      when 'Boolean' then return conditionCheck(expr, variable, cmd)
      when 'Variable' then return bindVariable(expr, variable, cmd)
      when 'Formular' then return calculate(expr, variable, cmd)
      when 'Branch' then return branch(expr, variable, cmd)
      when 'Loop' then return doLoop(expr, variable, cmd)
      when 'Action' then return doAction(expr, variable, cmd)
      else
        return getVar(expr, variable, cmd)

getTypeof = (expr) ->
  return 'Undefined' unless expr?
  return 'Boolean' if expr is true or expr is false
  return 'Undefined' unless typeof expr is 'object' or Array.isArray(expr)
  return 'Action' if expr.type?
  if getTypeof(expr.condition) is 'Boolean'
    return 'Branch' if expr.if?
    return 'Loop' if expr.while?
  for k, v of expr when k[1] is '_'
    return 'Variable' if k[0] is 'v'
  for k, v of expr
    switch k
      when '<', '>', '==', '>=', '<=', '!=', 'or', 'and', 'not'
        return 'Boolean'
      when '+', '-', '*', '/', '&', '|', '~' then return 'Formular'

  return 'Undefined'

branch = (expr, variable, cmd) ->
  if parse(expr.condition, variable, cmd) is true
    return parse(expr.if, variable, cmd)
  else if expr.else
    return parse(expr.else, variable, cmd)

doLoop = (expr, variable, cmd) ->
  while parse(expr.condition, variable, cmd) is true
    parse(expr.while, variable, cmd)

getVar = (kv, variable, cmd) ->
  return variable[kv] if variable? and variable[kv]?
  if cmd? and cmd.getEnvironment?().getVar?(kv)?
    return cmd.getEnvironment().getVar(kv)
  if Array.isArray(kv) then return kv.map( (k) -> return getVar(k) )
  return kv

doAction = (actions, variables, cmd) ->
  actions = [actions] unless Array.isArray(actions)
  env = cmd.getEnvironment() if cmd?
  for act in actions
    if act.trigger?
      variables = env.getTrigger(act.trigger).variables
    switch act.type
      when 'deleteVariable' then delete variables[act.name]
      when 'getProperty'
        local = doGetProperty(variables, act.key)
        if not local? and env? then return doGetProperty(env.variable(), act.key)
        return local
      when 'newVariable'
        variables[act.name] = parse(act.value, variables, cmd)
        return variables[act.name]
      when 'modifyVariable'
        if variables[act.name]?
          variables[act.name] = parse(act.value, variables, cmd)
        else if env.variable(act.name)?
          return env.variable(act.name, parse(act.value, variables, cmd))
      when 'delay'
        c = {id: 'Delay'}
        if act.delay? then c.delay = act.delay
        cmd = cmd.next(c)
      else
        a = {}
        a[k] = parse(v, variables, cmd) for k, v of act
        return env.doAction(a, variables, cmd) if env?


bindVariable = (variables, dummy, cmd) ->
  ret = {}
  for k, v of variables
    ret[k] = parse(v, variables, cmd)

  return ret

calculate = (formular, variables, cmd) ->
  for k, c of formular
    switch k
      when '+'
        return parse(c[0], variables, cmd) + parse(c[1], variables, cmd)
      when '-'
        return parse(c[0], variables, cmd) - parse(c[1], variables, cmd)
      when '*'
        return parse(c[0], variables, cmd) * parse(c[1], variables, cmd)
      when '/'
        return parse(c[0], variables, cmd) / parse(c[1], variables, cmd)
      when '&'
        return parse(c[0], variables, cmd) & parse(c[1], variables, cmd)
      when '|'
        return parse(c[0], variables, cmd) | parse(c[1], variables, cmd)
      when '~'
        return ~parse(c, variables, cmd)

class TriggerManager
  constructor: (@config) ->
    @triggers = {}
    @events = {}

  onEvent: (event, cmd) ->
    return false unless @events[event]?
    for i, t of @events[event] when @triggers[t]?
      @invokeTrigger(t, {}, cmd)

  doAction: (act, variables, cmd) ->
    switch act.type
      when 'installTrigger' then @installTrigger(act.name, variables, cmd)
      when 'removeTrigger' then @removeTrigger(act.name)
      when 'enableTrigger' then @enableTrigger(act.name)
      when 'disableTrigger' then @disableTrigger(act.name)
      when 'invokeTrigger' then @invokeTrigger(act.name, act.paramater, cmd)
      # TODO: action & trigger returnes values

  installTrigger: (name, variables, cmd) ->
    cfg = @config[name]
    throw Error('Unconfigured trigger:'+name) unless cfg?
    @triggers[name] = {
      variables: bindVariable(cfg.variable, variables, cmd),
      enable: true
    }
    if cfg.triggerEvent
      for e in cfg.triggerEvent
        @events[e] = [] unless @events[e]?
        @events[e].push(name)

  getTrigger: (name) -> @triggers[name]
  disableTrigger: (name) -> @triggers[name]?.enable = false
  enableTrigger:  (name) -> @triggers[name]?.enable = true
  removeTrigger:  (name) -> delete @triggers[name] #TODO: remove events
  invokeTrigger:  (name, paramaters, cmd) ->
    trigger = @triggers[name]
    return false unless trigger? and trigger.enable
    cfg = @config[name]
    if cfg.condition? and not parse(cfg.condition, trigger.variables, cmd)
      return false
    parse(cfg.action, trigger.variables, cmd)

exports.parse = parse
exports.TriggerManager = TriggerManager
exports.fileVersion = -1
