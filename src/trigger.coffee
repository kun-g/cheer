"use strict"

modifier = {
  1: { x:-1, y: 1 }, 2: { x: 0, y: 1 }, 3: { x: 1, y: 1 },
  4: { x:-1, y: 0 }, 5: { x: 0, y: 0 }, 6: { x: 1, y: 0 },
  7: { x:-1, y:-1 }, 8: { x: 0, y:-1 }, 9: { x: 1, y:-1 }
}

direction = {
  NorthWest:7, North:8, NorthEast: 9,
  West:4,      Center:5,East: 6,
  SouthWest:1, South:2, SouthEast: 3
}
areaShape = {
  Line: 0,
  Cross: 1,
  Square: 2,
  Triangle: 3
}

translatePos = (pos) ->
  x = pos % Dungeon_Width
  y = (pos-x) / Dungeon_Width
  return {x:x,y:y}

exports.translatePos =translatePos

angle_dir_map = []
angle_dir_map[direction.East      ] = [0,1, 15, 16]
angle_dir_map[direction.NorthEast ] = [1,3]
angle_dir_map[direction.North     ] = [3, 5]
angle_dir_map[direction.NorthWest ] = [5, 7]
angle_dir_map[direction.West      ] = [7,9]
angle_dir_map[direction.SouthWest ] = [9 ,11]
angle_dir_map[direction.South     ] = [11, 13]
angle_dir_map[direction.SouthEast ] = [13, 15]

initCalcDirFunc = ( cfg) ->
  cfg = cfg.map((elm) ->
    return elm.map((rd) ->
      return rd/8*Math.PI))

  inRange = (cfg, angle) ->
    for v, k in cfg
      if v?
        return k if v[0] <=angle < v[1]
        return k if (v.length is 4 ) and (v[0] <= angle < v[1] or v[2] <= angle < v[3])
    return direction.Center
  return  (src, tar) ->
    dx = tar.x - src.x
    dy = src.y - tar.y

    if dx is 0 and dy is 0
      return direction.Center
    
    angle = Math.atan(dy/dx)
    angle = Math.PI + angle if angle < 0
    angle+= Math.PI if  dy < 0 or (dy is 0 and dx < 0)
    return inRange(cfg, angle)

calcDirection = initCalcDirFunc( angle_dir_map)
exports.calcDirection = calcDirection

maskUnion = (one ,another) ->
  result = [].concat(one)
  for idx1, arr of another
    result[idx1] ?= []
    result[idx1][idx2] = true for isMask, idx2 in arr when isMask
  
  return result

printMask = (arr) ->
  for idx1 in [0..Dungeon_Height-1]
    arr1 = arr[idx1]
    if arr1?
      strArr =[]
      for idx in [0..Dungeon_Width-1]
        c = if arr1[idx] then '@' else '*'
        strArr.push(c)
      console.log(strArr.join('|'))
    else
      console.log('*|*|*|*|*')

selectLine = (x, y, direction, dFrom, length, result) ->
  mod = modifier[direction]
  result = [] unless result
  for i in [dFrom..dFrom+length-1] when 0<=y+mod.y*i<Dungeon_Height and 0<=x+mod.x*i<Dungeon_Width
    result[y+mod.y*i] = [] unless result[y+mod.y*i]
    result[y+mod.y*i][x+mod.x*i] = true
  return result

selectCross = (x, y, direction, dFrom, length) ->
  selector = [2, 4, 6, 8]
  if direction%2 then selector = [1, 3, 7, 9]
  ret = []
  for sel in selector
    selectLine(x, y, sel, dFrom, length+1, ret)
  return ret

selectSquare = (x, y, direction, dFrom, length, ground) ->
  if direction%2
    selector = [[8,3], [6,1], [2,7], [4,9]]
    adjust = 1
  else
    selector = [[7,6], [9,2], [1,8], [3,4]]
    adjust = 2

  ret = []
  for i in [dFrom..dFrom+length]
    for sel in selector
      mod = modifier[sel[0]]
      selectLine(x+mod.x*i, y+mod.y*i, sel[1], 0, i*adjust+1, ret)
  return ret

selectTriangle = (x, y, direction, dFrom, length, ground) ->
  localModifier = {
    7: [4,9], 8: [7,6], 9: [8,3],
    4: [1,8], 5: [5,5], 6: [9,2],
    1: [2,7], 2: [3,4], 3: [6,1]
  }
  ret = []
  for i in [dFrom..dFrom+length-1]
    mod = localModifier[direction][0]
    mod = modifier[mod]
    if direction%2
      selectLine(x+mod.x*i, y+mod.y*i, localModifier[direction][1], 0, i+1, ret)
    else
      selectLine(x+mod.x*i, y+mod.y*i, localModifier[direction][1], 0, 1+2*i, ret)
  return ret
handlers = {}
handlers[areaShape.Line] = selectLine
handlers[areaShape.Cross] = selectCross
handlers[areaShape.Square] = selectSquare
handlers[areaShape.Triangle] = selectTriangle

filterObject = (me, objects, filters, env) ->
  filters = [filters] unless Array.isArray(filters)
  result = (o for o in objects)
  for f in filters
    srcFaction = me.faction ? f.faction
    switch f.type
      when 'alive' then result = (p for p in result when p.isAlive())
      when 'same-faction' then result = (o for o in result when o.faction is srcFaction)
      when 'role-id' then result = (o for o in result when o.roleID is f.roleID)
      when 'visible' then result = (p for p in result when p.isVisible)
      when 'not-me' then result = (p for p in result when p.ref isnt me.ref)
      when 'same-block' then result = (p for p in result when p.pos is me.pos)
      when 'sort' then result.sort( (a, b) -> if (f.reverse) then b[f.by] - a[f.by] else a[f.by] - b[f.by] )
      when 'count' then result = result.slice(0, f.count)
      when 'different-faction' then result = (o for o in result when o.faction isnt srcFaction)
      else
        if not env? then return []
        switch f.type
          when 'target-faction-with-flag' then result = (o for o in result when env.getFactionConfig(srcFaction, o.faction, f.flag))
          when 'source-faction-with-flag' then result = (o for o in result when env.getFactionConfig(o.faction, srcFaction, f.flag))
          when 'target-faction-without-flag' then result = (o for o in result when not env.getFactionConfig(srcFaction, o.faction, f.flag))
          when 'source-faction-without-flag' then result = (o for o in result when not env.getFactionConfig(o.faction, srcFaction, f.flag))
          when 'shuffle' then result = shuffle(result, env.rand())
          when 'anchor'
            tmp = result

            f = JSON.parse(JSON.stringify(f))
            f.startDistance ?= 0
            f.offsetX ?= 0
            f.offsetY ?= 0
            if f.anchorPos?
              if Array.isArray(f.anchorPos)
                f.anchorPosList = f.anchorPos
              else
                f.anchorPosList = me.selectTarget({targetSelection:f.anchorPos}, env).map((e) -> e.pos)
            else
              f.anchorPosList = [0]

            dirTarPos = me.selectTarget({targetSelection:f.anchorDirPos}, env)?[0]?.pos if f.anchorDirPos?
            effectDir = []
            mask = f.anchorPosList.reduce((acc,pos) ->
              p = translatePos(pos)
              if f.direction?
                dir = f.direction
              else if dirTarPos?
                dir = calcDirection(p,translatePos(dirTarPos))
              else
                dir = direction.East
              effectDir.push(dir)
              mask = handlers[f.shape](p.x + f.offsetX, p.y + f.offsetY, dir, f.startDistance, f.length)
              return maskUnion(acc, mask)
            ,[])
            console.log('aP',f.anchorPosList, 'dirTarPos',dirTarPos)
            #printMask(mask)
            #console.log('result',result.map((e) ->e.pos).join(','))

            env.variable('effdirlst',effectDir)
            #console.log('filterObject', effectDir)
            result = result.filter((e) ->
              p = translatePos(e.pos)
              return mask[p.y]?[p.x]
            )
            #console.log('result after',result.map((e) ->e.pos).join(','))
  return result


exports.filterObject = filterObject

doGetProperty = (obj, key) ->
  if typeof key is 'string'
    properties = key.split('.')
  else
    properties = [key]
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
      when 'Time' then return moment(expr.time)
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
  return 'Time' if expr.time

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

# -----------------------------------
evaluateParameter = (expression) ->
  if typeof expression is 'string'
    if expression[0] is '$'
      return false
  else if typeof expression is 'object'
    throw 'NNNN'

  return expression

condition_and = (config, parameter) ->
  result = true
  for cond in config
    condition = new Condition(cond)
    result = result and condition.evaluate.apply(condition, parameter)
    return false unless result

  return result

condition_or = (config, parameter) ->
  result = false
  for cond in config
    condition = new Condition(cond)
    result = result or condition.evaluate.apply(condition, parameter)
    return true if result

  return result

class Condition
  constructor: (@config) ->
    @variable = {}

  addVariable: (key, value) ->
    @variable[key] = value
    return this

  fillUpParamter: (parameters) ->
    parameter_config = PredicateDB[@config.predicate].parameter
    return parameters unless parameter_config

    result = []
    for k, v of parameter_config
      if parameters?[v]
        result[k] = parameters[v]
      else
        result[k] = @config[v]

    result = result.map( (e) =>
      if isSequal(e)
        return executeSequal(e, @variable)
      else
        return e
    )
    return result

  executePredicator: (name, parameters) ->
    PredicateDB[name].func.apply(this, @fillUpParamter.apply(this, parameters))

  evaluate: () ->
    return true unless @config

    if typeof @config is 'string'
      result = @executePredicator(@config, arguments)
    else if Array.isArray(@config)
      result = condition_and(@config, arguments)
    else if typeof @config is 'object'
      if @config.or
        result = condition_or(@config.or, arguments)
      else if @config.not
        condition = new Condition(@config.not)
        result = not condition.evaluate.apply(condition, arguments)
      else if @config.and
        result = condition_and(@config.and, arguments)
      else
        result = @executePredicator(@config.predicate, arguments)
    else
      result = false

    @varialbe = {}
    return result

exports.Condition = Condition

class Action
  constructor: (@config) ->
    @variable = {}

  addVariable: (key, value) ->
    @variable[key] = value
    return this

  fillUpParamter: (parameters) ->
    parameter_config = ActionDB[@config.action].parameter
    return parameters unless parameter_config

    result = []
    for k, v of parameter_config
      if parameters?[v]
        result[k] = parameters[v]
      else
        result[k] = @config[v]

    result = result.map( (e) =>
      if isSequal(e)
        return executeSequal(e, @variable)
      else
        return e
    )
    return result

  execute: (parameters) -> ActionDB[@config.action].func.apply(this, @fillUpParamter(parameters))

exports.Action = Action

class Trigger
  constructor: (@config, @creator) ->

  conditionIsPassed: (parameters) ->
    return true unless @config.condition
    return (new Condition(@config.condition)).evaluate(parameters)

  executeAction: (parameters) ->
    action = new Action(@config.action)
    action.execute(parameters)

  execute: (parameters) ->
    if @conditionIsPassed(parameters)
      @executeAction(parameters)

exports.Trigger = Trigger

ActionDB = {}
ActionDB.modify_property = {
  parameter: ['object', 'key', 'value'],
  func: (object, key, value) -> object[key] = value
}

PredicateDB = {}
PredicateDB.alive = {
  parameter: ['object'],
  func: (object) -> if object.isAlive then return object.isAlive() else return false
}

parameter_config = ['value1', 'value2']
PredicateDB['>'] =  {parameter: parameter_config, func: (a, b) -> return a > b }
PredicateDB['<'] =  {parameter: parameter_config, func: (a, b) -> return a < b }
PredicateDB['='] =  {parameter: parameter_config, func: (a, b) -> return a == b}
PredicateDB['>='] = {parameter: parameter_config, func: (a, b) -> return a >= b}
PredicateDB['<='] = {parameter: parameter_config, func: (a, b) -> return a <= b}
PredicateDB['!='] = {parameter: parameter_config, func: (a, b) -> return a != b}

PredicateDB.same = {
  parameter: ['parameters'],
  func: (parameters) ->
    mask = {}
    mask[v] = 1 for k, v of parameters

    return  Object.keys(mask).length is 1
}

parseVariable = (expr, variables) ->
  return expr unless variables and typeof expr is 'string'
  return expr unless expr[0] is '$'
  expr = expr.slice(1) # remove '$'
  keys = expr.split('.')
  obj = variables[keys.shift()]
  while keys.length
    return null unless obj
    obj = obj[keys.shift()]
  return obj

isSequal = (expr) -> expr?.query?

executeSequal = (expr, variables) ->
  query = new Query(expr.query)

  obj = parseVariable(expr.object, variables)
  if isSequal(obj) then obj = executeSequal(obj, variables)
  key = parseVariable(expr.key, variables)
  if isSequal(key) then key = executeSequal(key, variables)

  return query.evaluate(obj, key)


exports.executeSequal = executeSequal

class Query
  constructor: (@config, @creator) ->
    @func = SequalDB[@config]

  evaluate: () -> @func.apply(this, arguments)

exports.Query = Query

SequalDB = {
  get_property: () -> doGetProperty(arguments[0], arguments[1])

  select_target: () ->
    pool = getPool()
    for predicator in conditions
      pool = pool.filter((e) -> predicator(e))

    return pool
}
exports.direction = direction
exports.areaShape = areaShape
