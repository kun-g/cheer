"use strict"
libTime = require('./timeUtils.js')
moment = require('./moment')
{Serializer, registerConstructor} = require './serializer'

class Counter
  constructor: (@config) ->
    @counter = config.initial_value
    @time = null
    Object.defineProperty(this, 'config', {enumerable:false, writable: false, configurable: false})

  isFulfiled: (time) ->
    @update(time)
    return @counter>=@config.uplimit if @config.uplimit
    return false

  notFulfiled: (time) -> not @isFulfiled(time)

  isCounted: (time) ->
    theData = { ThisCounter: { time: @time } }
    return libTime.verify(time, @config.count_down, theData) if @config.count_down
    return false

  notCounted: (time) -> not @isCounted(time)

  update: (time) -> @incr(0, time)

  decr: (delta, time) -> @incr(-delta, time)

  incr: (delta, time) ->
    duration = @config.duration
    units = @config.units

    theData = { ThisCounter: { time: @time } }

    time = moment(time)

    duration = @config.duration
    if duration
      if !libTime.verify(time, duration, theData)
        @counter = 0

    combo = @config.combo
    if combo
      if !libTime.verify(time, combo, theData)
        @counter = 0

    if @config.count_down and @isCounted(time) then delta = 0

    uplimit = @config.uplimit
    if uplimit && @counter + delta > uplimit
      delta = uplimit - @counter

    @counter += delta
    if delta then @time = time.format()
    return @

  reset: () -> @counter = config.initial_value

  fulfill: () ->
    if @config.uplimit
      @counter = config.uplimit

exports.Counter = Counter
