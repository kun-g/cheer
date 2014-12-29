"use strict"
libTime = require('./timeUtils.js')
libCounter = require('./counter.js')

utils = {
  libTime: libTime,
  libCounter: libCounter
}

class Campaign
  constructor: (@config) ->

  getLogicOperator: (obj) ->
    keys = ['or', 'and', 'not']
    for key in keys
      if obj[key] then return key
    return null

  conditionCheck: (condition, object, time) ->
    return true unless condition

    flag = true
    if Array.isArray(condition)
      flag = condition.reduce((r, e) =>
        if !r then return r
        switch (e.type)
          when 'counter'
            return @getInfo(object).counter[e.func](time)
          when 'time'
            thisData = { Timestamp: object.timestamp }
            return libTime.verify(time, e.timeExpr, thisData)
          when 'function'
            thisData = { object: object, time: time }
            return e.func(thisData, utils)
      , true)
    else
      switch (@getLogicOperator(condition))
        when 'or' then return condition.or.reduce((r, e) =>
          if r then return r
          return r || @conditionCheck([e], object, time)
        , false)
        when 'and' then return condition.and.reduce((r, e) =>
          if !r then return r
          return r && @conditionCheck([e], object, time)
        , true)
        when 'not' then return !@conditionCheck([condition.not], object, time)
    return flag

  canReset: (object, time) -> @conditionCheck(@config.reset_condition, object, time)

  isActive: (object, time) ->
    if @config.storeType and object.type isnt @config.storeType then return false

    return @conditionCheck(@config.available_condition, object, time)

  reset: (object, time) ->
    return unless @config.reset_action
    for action in this.config.reset_action
      switch (action.type)
        when 'function'
          thisData = { object: object, time: time }
          action.func(thisData, utils)

  getInfo: (object, time) ->
    result = {}

    counterConfig = @config.counter
    if counterConfig
      counterKey = counterConfig.key
      if !object.counters[counterKey]
        object.counters[counterKey] = new libCounter.Counter(counterConfig)
      result.counter = object.counters[counterKey]

    return result
#
#Campaign.prototype.onEvent = function (object, event) {
#  if (!this.config.event) return false;
#  
#  object.doAction(this.config.event.action);
#}
#
#function doAction (actions) {
#  for (var k in actions) {
#    var action = actions[k];
#    var prize = action.prize;
#
#  }
#      //action: [
#      //{
#      //  prize: [{
#      //    method: 'instant',
#      //    prize: [{ type: 'incr counter', name: 'goblin', count: 1 }]
#      //  }]
#      //}
#      //]
#}
exports.Campaign = Campaign
