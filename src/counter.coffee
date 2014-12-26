"use strict"
libTime = require('./timeUtils.js')
moment = require('./moment')
{Serializer, registerConstructor} = require './serializer'

class Counter extends Serializer
  constructor: (@config) ->
    savingCfg = {
      config: config,
      counter: config.initial_value,
      time: moment().format(),
    }

    super(config, savingCfg, {})

  isFulfiled: (time) ->
    @update(time)
    return @counter>@counter.uplimit if @config.uplimit
    return false

  notFulfiled: (time) -> not @isFulfiled(time)

  update: (time) -> @incr(0, time)

  decr: (delta, time) -> @incr(-delta, time)

  incr: (delta, time) ->
    duration = @config.duration
    units = @config.units

    theData = { ThisCounter: { time: @time } }

    time = moment(time)
    if delta then @time = time.format()

    if @time
      duration = @config.duration
      if duration
        if !libTime.verify(time, duration, theData)
          @counter = 0

      combo = @config.combo
      if combo
        if !libTime.verify(time, combo, theData)
          @counter = 0

      countDown = @config.count_down
      if countDown
        if libTime.verify(time, countDown, theData)
          delta = 0

    uplimit = @config.uplimit
    if uplimit && @counter + delta > uplimit
      delta = uplimit - @counter

    @counter += delta
    return @

  reset: () -> @counter = config.initial_value

  fulfill: () ->
    if @config.uplimit
      @counter = config.uplimit

exports.Counter = Counter
