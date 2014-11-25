moment = require('./moment')
_s = require("./underscore.string.js")
_ = require("./underscore.js")

_.mixin(_s.exports())
_.mixin({ includeString: _s.include, reverseString: _s.reverse })

complexVerify = (time, exp) ->
  switch getLogicOperator(exp)
    when 'or' then return exp.or.reduce((r, e) ->
      if r then return r
      return r or doVerify(time, e)
    , false)

    when 'and' then return exp.and.reduce((r, e) ->
      if not r then return r
      return r && doVerify(time, e)
    , true)

    when 'not' then return !doVerify(time, exp.not)

getLogicOperator = (obj) ->
  keys = ['or', 'and', 'not']
  for k, key of keys
    if obj[key] then return key
  return null

doVerify = (time, config) ->
  if getLogicOperator(config) then return complexVerify(time, config)

  result = true
  range = moment(config.time)
  if range
    if config.units
      result = result && range.isSame(time, config.units)

    duration = config.duration
    if duration
      localDuration = moment.duration({to:time, from: range})
      result = result && localDuration < moment.duration(duration)

  from = config.from
  to = config.to
  if from
    result = result && time.isAfter(from)

  if to
    result = result && time.isBefore(to)

  return result

parseMoment = (arg, theObject) ->
  return moment() unless arg
  if moment.isMoment(arg) then return arg

  if typeof arg is 'string'
    if _(arg).includeString('@')
      tokens = _(arg).words("@")
      field = tokens[0]
      object = theObject[tokens[1]]
      arg = object[field]
    arg = moment(arg)
  else if typeof arg is 'object'
    time = parseMoment(arg.time, theObject)

    if arg.startOf then time = time.startOf(arg.startOf)
    if arg.endOf then time = time.endOf(arg.endOf)
    if arg.offset then time = time.add(moment.duration(arg.offset))

    arg = time
  return arg

parseDuration = (exp, theObject) ->
  config = { }
  operator = getLogicOperator(exp)
  if operator
    tempFunc = (e) -> return parseDuration(e, theObject)
    config[operator] = exp[operator].map(tempFunc)
  else
    config.units = exp.units
    if exp.time
      config.time = parseMoment(exp.time, theObject)
      if exp.duration then config.duration = moment.duration(exp.duration)
    else if exp.from
      config.from = parseMoment(exp.from, theObject)
    else if exp.to
      config.to = parseMoment(exp.to, theObject)

  return config

verify = (time, durationExp, theData) ->
  time = parseMoment(time, theData)
  theData.Arguments = { time: time }
  timeExp = parseDuration(durationExp, theData)
  return doVerify(time, timeExp)

exports.verify = verify

exports.diff = (to, from) -> return moment.duration({from: from, to: to})

exports.currentTime = () -> moment().format()
