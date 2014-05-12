{conditionCheck} = require('./trigger')
moment = require('moment')

# React Programming
destroyReactDB = (obj) ->
  return false unless obj
  for k, v of obj when typeof v is 'object'
    destroyReactDB(v)
    delete obj[k]
  if obj.destroyReactDB then obj.destroyReactDB()
  if obj.newProperty then obj.newProperty = null
  if obj.push then obj.push = null
  obj.destroyReactDB = null

exports.destroyReactDB = destroyReactDB

tap = (obj, key, callback, invokeFlag = false) ->
  return false if typeof obj[key] is 'function'
  unless obj.reactDB?
    Object.defineProperty(obj, 'reactDB', {
      enumerable : false,
      configurable : true,
      value: { }
    })
    Object.defineProperty(obj, 'destroyReactDB', {
      enumerable : false,
      configurable : true,
      value: () ->
        return null unless obj?.reactDB
        for k, v of obj.reactDB
          v.value = null
          v.hooks = null
        obj.reactDB = null
        obj = null
    })

  unless obj.reactDB[key]?
    obj.reactDB[key] = {
      value: obj[key],
      hooks: [callback]
    }
    theCB = (val) ->
      return null unless obj.reactDB?[key]?.hooks?
      cb(key, val) for cb in obj.reactDB[key].hooks when cb?
      return obj.reactDB[key].value = val

    Object.defineProperty(obj, key, {
      get : () ->
        return null unless obj?.reactDB?[key]?
        return obj.reactDB[key].value
      ,
      set : theCB,
      enumerable : true,
      configurable : true
    })

    if typeof obj[key] is 'object' then tapObject(obj[key], theCB)
  else
    obj.reactDB[key].hooks.push(callback)
  if invokeFlag then callback(key, obj[key])

tapObject = (obj, callback) ->
  return false unless obj?
  theCallback = () -> callback(obj)
  tabNewProperty = (key, val) ->
    obj[key] = val
    tap(obj, key, theCallback)
    callback(obj)

  for k, v of obj
    tap(obj, k, theCallback)

  config = {
    value: tabNewProperty,
    enumerable : false,
    configurable : true,
    writable : false,
  }

  if not obj.newProperty?
    Object.defineProperty(obj, 'newProperty', config)
    if Array.isArray(obj)
      Object.defineProperty(obj, 'push', {
        value: (val) -> @newProperty(@length, val)
      })
exports.tap = tap

# Leaderboard
exports.initLeaderboard = (config) ->
  localConfig = []
  srvCfg = {}

  generateHandler = (dbKey, cfg) ->
    return (name, value) ->
      require('./dbWrapper').updateLeaderboard(dbKey, name, value)

  for key, cfg of config
    localConfig[key] = { func: generateHandler(cfg.name, cfg) }
    localConfig[key][k] = v for k, v of cfg

  dbLib = require('./db')
  dbLib.getServerConfig('Leaderboard', (err, arg) ->
    if arg then srvCfg = JSON.parse(arg)
    
    for key, cfg of config when not srvCfg[cfg.name]
      srvCfg[cfg.name] = currentTime()

    dbLib.setServerConfig('Leaderboard', JSON.stringify(srvCfg))
  )

  exports.assignLeaderboard = (player) ->
    localConfig.forEach( (v) ->
      return false unless player.type is v.type
      tmp = v.key.split('.')
      key = tmp.pop()
      obj = player
      if tmp.length
        obj = require('./trigger').doGetProperty(player, tmp.join('.')) ? player
      obj[key] = v.initialValue unless obj[key]?
      v.func(player.name, obj[key])
      tap(obj, key, (dummy, value) ->
        v.func(player.name, value)
      )
    )

  tickLeaderboard = (board, cb) ->
    cfg = localConfig[board]
    if cfg.resetTime and matchDate(srvCfg[cfg.name], currentTime(), cfg.resetTime)
      require('./dbWrapper').removeLeaderboard(cfg.name, cb)

  exports.getPositionOnLeaderboard = (board, name, from, to, cb) ->
    tickLeaderboard(board)
    cfg = localConfig[board]
    require('./db').queryLeaderboard(cfg.name, name, from, to, cb)

# Time util
currentTime = (needObject) ->
  obj = moment().zone("+08:00")
  if needObject
    return obj
  else
    return obj.format(time_format)
exports.currentTime = currentTime

diffDate = (date, today, flag = 'day') ->
  return null unless date
  date = moment(date).zone("+08:00").startOf('day') if date
  today = moment(today).zone("+08:00").startOf('day')
  duration = moment.duration(today.diff(date))
  switch flag
    when 'second' then return duration.asSeconds()
    when 'minite' then return duration.asMinites()
    when 'hour' then return duration.asHours()
    when 'day' then return duration.asDays()
    when 'month' then return duration.asMonths()
    when 'year' then return duration.asYears()
exports.diffDate = diffDate

matchDate = (date, today, rule) ->
  return false unless date
  date = moment(date).zone("+08:00")
  today = moment(today).zone("+08:00")

  if rule.weekday?
    date = date.weekday(rule.weekday)
  else if rule.monthday?
    date = date.date(rule.monthday)

  if rule.month then date = date.month(rule.month)
  if rule.day then date = date.day(rule.day)
  date = date.hour(rule.hour ? 0)
  date = date.minute(rule.minute ? 0)
  date = date.second(rule.second ? 0)

  return date <= today
  
exports.matchDate = matchDate

genCampaignUtil = () ->
  return {
    diffDay: (date, today) -> return not date? or diffDate(date, today, 'day') isnt 0,
    currentTime: currentTime,
    today: moment()
  }
exports.genUtil = genCampaignUtil

initCampaign = (me, allCampaign, abIndex) ->
  ret = []
  util = genCampaignUtil()
  for key, e of allCampaign when me.getType() is e.storeType
    if key is 'event_daily'
      ret = ret.concat(initDailyEvent(me, 'event_daily', e))
    else
      if e.canReset(me, util) then e.reset(me, util)
      count = me.counters[key] ? 0
      ret.push({
        NTF: Event_BountyUpdate,
        arg: { bid: e.id, sta: e.actived, cnt: e.count - count}
      })
  return ret

# campaign
initDailyEvent = (me, key, e) ->
  ret = []
  if e.prev? and me[e.prev]? and me[e.prev].status isnt 'Done'
    return []
  if e.flag? and not me.flags[e.flag]?
    return []

  if not me[key]?
    me[key] = {}
    me.attrSave(key, true)
  if e.daily
    if not me[key].date or diffDate(me[key].date, currentTime()) isnt 0
      me[key].newProperty('status', 'Init')
      me[key].newProperty('date', currentTime())
      if key is 'event_daily'
        me[key].newProperty('rank', me.battleForce/24 - 3)
        if me[key].rank < 1 then me[key].rank = 1
        me[key].newProperty('reward', [{type: PRIZETYPE_GOLD, count: Math.floor(me[key].rank*18)}])

  if e.quest and Array.isArray(e.quest) and me[key].status is 'Init'
    me[key].newProperty('quest', shuffle(e.quest, Math.random()).slice(0, e.steps))
    me[key].newProperty('step', 0)
    goldCount = Math.ceil(me[key].rank*6)
    diamondCount = Math.ceil(me[key].rank/10)
    goldCount = Math.floor(me[key].rank*6)
    me[key].newProperty('stepPrize', [
      [{type: PRIZETYPE_GOLD, count: goldCount}, {type: PRIZETYPE_ITEM, value: 0, count: diamondCount}],
      [{type: PRIZETYPE_GOLD, count: goldCount}, {type: PRIZETYPE_ITEM, value: 0, count: diamondCount}, {type: PRIZETYPE_ITEM, value: 534, count: 5}],
      [{type: PRIZETYPE_GOLD, count: goldCount}, {type: PRIZETYPE_ITEM, value: 0, count: diamondCount}, {type: PRIZETYPE_ITEM, value: 535, count: 2}],
      [{type: PRIZETYPE_GOLD, count: goldCount}, {type: PRIZETYPE_ITEM, value: 0, count: diamondCount}, {type: PRIZETYPE_ITEM, value: 536, count: 1}]
    ])
  quest = me[key].quest
  if Array.isArray(quest)
    quest = quest[me[key].step]
  switch me[key].status
    when 'Claimed'
      if quest? then delete me.quests[quest]
      me[key].step++
      if me[key].step == e.steps
        me[key].status = 'Complete'
      else if me[key].step > e.steps
        me[key].status = 'Done'
      else
        me[key].status = 'Ready'
        quest = me[key].quest
        if Array.isArray(quest)
          quest = quest[me[key].step]
        if quest? then delete me.quests[quest]
      return ret.concat(initDailyEvent(me, key, e))
    when 'Init'
      me[key].status = 'Ready'
      return ret.concat(initDailyEvent(me, key, e))
    when 'Ready', 'Complete', 'Done'
      if quest?
        if me.isQuestAchieved(quest)
          me[key].status = 'Complete'
        else if not me.quests[quest]
          ret = ret.concat(me.acceptQuest(quest))

      evt = {
        NTF: Event_UpdateDailyQuest,
        arg: { stp: me.event_daily.step, prz: me.event_daily.reward }
      }
      if me.event_daily.quest[me.event_daily.step]?
        evt.arg.qst = me.event_daily.quest[me.event_daily.step]
      if me.event_daily.stepPrize[me.event_daily.step]?
        evt.arg.cpz = me.event_daily.stepPrize[me.event_daily.step]

      ret.push(evt)
  return ret
exports.initCampaign = initCampaign

exports.initCalcDungeonBaseRank = (me) ->
  if me.event_daily? and me.event_daily.step < 4
    modifier = [0.8, 1, 1, 1.2]
    return me.event_daily.rank*modifier[me.event_daily.step]

actCampaign = (me, key, config, handler) ->
  initCampaign(me, config)
  return [false, 'NoData'] unless me[key]?

  switch me[key].status
    when 'Ready'
      quest = me[key].quest
      if Array.isArray(quest)
        quest = quest[me[key].step]
      stage = queryTable(TABLE_QUEST, quest).stage ? 1
      if stage? then return me.startDungeon(stage, true, handler)
    when 'Complete'
      if me[key].step < config[key].steps
        prize = me[key].stepPrize[me[key].step]
      else
        if me[key].reward
          prize = me[key].reward
        else if config[key].reward
          prize = config[key].reward
      ret = me.claimPrize(prize)
      me[key].status = 'Claimed'
      ret = ret.concat(initCampaign(me, config))
    when 'Done' then ret = [].concat(ret)
    else throw Error('WrongCampainStatus'+me[key].status)
  if handler
    handler(null, ret)
  else
    return ret

exports.proceedCampaign = actCampaign

exports.events = {
    "event_daily": {
      "flag": "daily",
      "resetTime": { hour: 8 },
      "storeType": "player",
      "daily": true,
      "reward": [
        { "prize":{ "type":0, "value":33, "count":1 }, "weight":1 },
        { "prize":{ "type":0, "value":34, "count":1 }, "weight":1 },
        { "prize":{ "type":0, "value":35, "count":1 }, "weight":1 },
        { "prize":{ "type":0, "value":36, "count":1 }, "weight":1 },
        { "prize":{ "type":0, "value":37, "count":1 }, "weight":1 }
      ],
      "steps": 4,
      "quest": [
        128, 129, 130, 131, 132, 133, 134, 135,
        136, 137, 138, 139, 140, 141, 142, 143,
        144, 145, 146, 147, 148, 149, 150, 151
      ]

    },
    goblin: {
      storeType: "player",
      id: 0,
      actived: 1,
      count: 3,
      canReset: (obj, util) ->
        return (util.diffDay(obj.timestamp.goblin, util.today) && util.today.hour() >= 8)
      ,
      reset: (obj, util) ->
        obj.timestamp.newProperty('goblin', util.currentTime())
        obj.counters.newProperty('goblin', 0)
    },
#   event_robbers: {
#     storeType: "player",
#     id: 0,
#     actived: 1,
#     count: 5,
#     canReset: (obj, util) ->
#       return (!util.diffDay(obj.timestamp.robbers, util.today) &&
#         util.today.hour() >= 8)
#     ,
#     reset: (obj, util) ->
#       obj.timestamp.robbers = util.currentTime()
#       obj.counters.robbers = 0
#   },
#   event_weapon: {
#     storeType: "player",
#     id: 1,
#     actived: 1,
#     count: 5,
#     canReset: (obj, util) ->
#       return !util.diffDay(obj.timestamp.weapon, util.today)
#     ,
#     reset: (obj, util) ->
#       obj.timestamp.weapon = util.currentTime()
#       obj.counters.weapon = 0
#     ,
#     stageID: 1024
#   },
#   event_enhance: {
#     id: 2,
#     storeType: "player",
#     actived: 1,
#     count: 5,
#     canReset: (obj, util) ->
#       return !util.diffDay(obj.timestamp.enhance, util.today)
#     ,
#     reset: (obj, util) ->
#       obj.timestamp.enhance = util.currentTime()
#       obj.counters.enhance = 0
#     ,
#     stageID: 1024
#   }
#  "event_energy": {
#    "type": "func",
#    "storeType": "player",
#    "condition": { "cdType": "daily", "time": ["0800", "1200", "1800"], "duration": 60 },
#    "action": {"type": "restoreEnergy"}
#  },
#  "event_goldenSlime": {
#    "type": "randomDungeon",
#    "storeType": "player",
#    "accessCount": 5,
#    "condition": { "cdType": "daily" },
#    "dungeon": [{"weight": 1, "dungeon": 1}]
#  },
#  "globalEvent_classHall": {
#    "type": "dungeon",
#    "completeCount": 1000,
#    "storeType": "global",
#    "condition": { "cdType": "daily" },
#    "action": { "type": "setGlobalFlag", "key": "classHall", "value": true}
#  }
}

exports.splicePrize = (prize) ->
  goldPrize = { type: PRIZETYPE_GOLD, count: 0 }
  xpPrize = { type: PRIZETYPE_EXP, count: 0 }
  wxPrize = { type: PRIZETYPE_WXP, count: 0 }
  otherPrize = []
  prize.forEach( (p) ->
    return [] unless p?
    switch p.type
      when PRIZETYPE_WXP then wxPrize.count += p.count
      when PRIZETYPE_EXP then xpPrize.count += p.count
      when PRIZETYPE_GOLD then goldPrize.count += p.count
      else otherPrize.push(p)
  )
  return {
    goldPrize: goldPrize,
    xpPrize: xpPrize,
    wxPrize: wxPrize,
    otherPrize: otherPrize
  }

exports.generatePrize = (cfg, dropInfo) ->
  return [] unless cfg?
  reward = dropInfo
    .reduce( ((r, p) -> return r.concat(cfg[p]) ), [])
    .filter((p) -> p and Math.random() < p.rate )
    .map((g) ->
      e = selectElementFromWeightArray(g.prize, Math.random())
      return e
    )

updateLockStatus = (curStatus, target, config) ->
  return [] unless curStatus
  ret = []
  for id, cfg of config
    unlockable = true
    if cfg.cond? then unlockable = unlockable and conditionCheck(cfg.cond, target)
    if unlockable and not curStatus[id]? then ret.push(+id)
  return ret
exports.updateLockStatus = updateLockStatus

exports.calculateTotalItemXP = (item) ->
  return 0 unless item.xp?
  levelTable = [0, 1, 2, 3, 4]
  upgrade = queryTable(TABLE_UPGRADE)
  xp = item.xp
  for i, cfg of upgrade when levelTable[item.quality] <= i < item.rank
    xp += cfg.xp
  return xp
