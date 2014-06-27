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

dbLib = require('./db')
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
      field = tmp.pop()
      obj = player
      if tmp.length
        obj = require('./trigger').doGetProperty(player, tmp.join('.')) ? player
      if v.initialValue? and not (typeof obj[field] isnt 'undefined' and obj[field])
        obj[field] = 0
        if typeof v.initialValue is 'number'
          obj[field] = v.initialValue
        else if v.initialValue is 'length'
          require('./db').queryLeaderboardLength(field, (err, result) ->
            obj[field] = +result
            obj.saveDB()
          )

      v.func(player.name, obj[field])
      tap(obj, field, (dummy, value) ->
        v.func(player.name, value)
      )
    )

  tickLeaderboard = (board, cb) ->
    cfg = localConfig[board]
    if cfg.resetTime and matchDate(srvCfg[cfg.name], currentTime(), cfg.resetTime)
      require('./dbWrapper').removeLeaderboard(cfg.name, cb)
      srvCfg[cfg.name] = currentTime()
      dbLib.setServerConfig('Leaderboard', JSON.stringify(srvCfg))

  exports.getPositionOnLeaderboard = (board, name, from, to, cb) ->
    console.log('getPositionOnLeaderboard',board, name, from, to)
    tickLeaderboard(board)
    cfg = localConfig[board]
    require('./db').queryLeaderboard(cfg.name, name, from, to, (err, result) ->
      result.board = result.board.reduce( ( (r, l, i) ->
        if i%2 is 0
          r.name.push(l)
        else
          r.score.push(l)
        return r
      ), {name: [], score: []})
      cb(err, result)
    )

exports.array2map = (keys, value) ->
  size = keys.length
  value.reduce( ( ( r, l , i) ->
    keyIdx = i % size
    r[keys[keyIdx]].push(l)
    return r
  ),{})

exports.warpRivalLst = (lst) ->
  return lst.reduce( ( (r, l, i) ->
    if l.length == 2 then r.name.push(l[0]) and r.rnk.push(+l[1])
    return r
  ), {name: [], rnk: []})

# Time util
currentTime = (needObject) ->
  obj = moment()
  if needObject
    return obj
  else
    return obj.format(time_format)
exports.currentTime = currentTime

diffDate = (date, today, flag = 'day') ->
  return null unless date
  date = moment(date).startOf('day') if date
  today = moment(today).startOf('day')
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
  date = moment(date)
  today = moment(today)

  if rule.weekday?
    date = date.weekday(rule.weekday)
  else if rule.monthday?
    date = date.date(rule.monthday)

  if rule.month then date = date.month(rule.month)
  if rule.day then date = date.add('day', rule.day)
  date = date.set('hour', rule.hour ? 0)
  date = date.set('minute', rule.minute ? 0)
  date = date.set('second', rule.second ? 0)

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
      if e.canReset?(me, util) then e.reset(me, util)
      if e.id?
        actived = e.actived
        if typeof actived is 'function' then actived = actived(me, util)
        evt = { NTF: Event_BountyUpdate, arg: { bid: e.id, sta: actived} }
        count = me.counters[key] ? 0
        if e.count then evt.arg.cnt = e.count - count
        if key is 'hunting'
          if not moment().isSame(gHuntingInfo.timestamp, 'day') or
             not gHuntingInfo.timestamp?
            gHuntingInfo.timestamp = currentTime()
            gHuntingInfo.stage = e.stages[rand()%e.stages.length]
            dbLib.setServerConfig('huntingInfo', JSON.stringify(gHuntingInfo))
          evt.arg.stg = +gHuntingInfo.stage
        ret.push(evt)
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
      e.quest.forEach( (q) -> delete me.quests[q])
      me[key].newProperty('status', 'Init')
      me[key].newProperty('date', currentTime())
      if key is 'event_daily'
        me[key].newProperty('rank', Math.ceil(me.battleForce*0.04))
        if me[key].rank < 1 then me[key].rank = 1
        me[key].newProperty('reward', [{type: PRIZETYPE_DIAMOND, count: 50}])

  if e.quest and Array.isArray(e.quest) and me[key].status is 'Init'
    me[key].newProperty('quest', shuffle(e.quest, Math.random()).slice(0, e.steps))
    me[key].newProperty('step', 0)
    goldCount = Math.ceil(me.battleForce)
    diamondCount = Math.ceil(me[key].rank/10)
    me[key].newProperty('stepPrize', [
      [{type: PRIZETYPE_ITEM, value: 538, count: 1}],
      [{type: PRIZETYPE_GOLD, count: goldCount}],
      [{type: PRIZETYPE_ITEM, value: 540, count: 1}],
      [{type: PRIZETYPE_DIAMOND, count: 10}]
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
        return util.diffDay(obj.timestamp.goblin, util.today)
      ,
      reset: (obj, util) ->
        obj.timestamp.newProperty('goblin', util.currentTime())
        obj.counters.newProperty('goblin', 0)
    },

    enhance: {
      storeType: "player",
      id: 1,
      actived: 1,
      count: 3,
      canReset: (obj, util) ->
        return ( util.diffDay(obj.timestamp.enhance, util.today)) and (
          util.today.weekday() is 2 or
          util.today.weekday() is 4 or
          util.today.weekday() is 6 or
          util.today.weekday() is 0
        )
      ,
      reset: (obj, util) ->
        obj.timestamp.newProperty('enhance', util.currentTime())
        obj.counters.newProperty('enhance', 0)
    },

    weapon: {
      storeType: "player",
      id: 2,
      actived: 1,
      count: 3,
      canReset: (obj, util) ->
        return (util.diffDay(obj.timestamp.weapon, util.today)) and (
          util.today.weekday() is 1 or
          util.today.weekday() is 3 or
          util.today.weekday() is 5 or
          util.today.weekday() is 0
        )
      ,
      reset: (obj, util) ->
        obj.timestamp.newProperty('weapon', util.currentTime())
        obj.counters.newProperty('weapon', 0)
    },

    infinite: {
      storeType: "player",
      id: 3,
      actived: 0,
      canReset: (obj, util) ->
        return (util.today.hour() >= 8 && util.diffDay(obj.timestamp.infinite, util.today))
      ,
      reset: (obj, util) ->
        obj.timestamp.newProperty('infinite', util.currentTime())
        obj.stage[120].newProperty('level', 0)
    },

    hunting: {
      storeType: "player",
      id: 4,
      actived: 0,
      stages: [121, 122, 123, 125, 126, 127, 128, 129, 130, 131, 132],
      canReset: (obj, util) ->
        return (util.diffDay(obj.timestamp.hunting, util.today))
      ,
      reset: (obj, util) ->
        obj.timestamp.newProperty('hunting', util.currentTime())
        stages = [121, 122, 123, 125, 126, 127, 128, 129, 130, 131, 132]
        for s in stages when obj.stage[s]
          obj.stage[s].newProperty('level', 0)
        obj.counters.newProperty('monster', 0)
    },

    monthCard: {
      storeType: "player",
      id: -1,
      actived: (obj, util) ->
        return 0 unless obj.counters.monthCard
        return 1 unless obj.timestamp.monthCard
        return 0 if moment().isSame(obj.timestamp.monthCard, 'day')
        return 1
    }
}

exports.intervalEvent = {
#  infinityDungeonPrize: {
#    time: { hour: 13 },
#    func: (libs) ->
#      cfg = [
#        {
#          from: 0,
#          to: 0,
#          mail: {
#            type: MESSAGE_TYPE_SystemReward,
#            src:  MESSAGE_REWARD_TYPE_SYSTEM,
#            prize: [{ type: 2, count: 50},
#                    { type: 0,value:869, count: 1}],
#            tit: "铁人试炼排行奖励",
#            txt: "恭喜你成为铁人试炼冠军，点击领取奖励。"
#          }
#        },
#        {
#          from: 1,
#          to: 4,
#          mail: {
#            type: MESSAGE_TYPE_SystemReward,
#            src:  MESSAGE_REWARD_TYPE_SYSTEM,
#            prize: [{ type: 2, count: 20},
#                    { type: 0,value:868, count: 1}],
#            tit: "铁人试炼排行奖励",
#            txt: "恭喜你进入铁人试炼前五，点击领取奖励。"
#          }
#        },
#        {
#          from: 5,
#          to: 9,
#          mail: {
#            type: MESSAGE_TYPE_SystemReward,
#            src:  MESSAGE_REWARD_TYPE_SYSTEM,
#            prize: [{ type: 2, count: 10},
#                    { type: 0,value:867, count: 1}],
#            tit: "铁人试炼排行奖励",
#            txt: "恭喜你进入铁人试炼前十，点击领取奖励。"
#          }
#        }
#      ]
#      cfg.forEach( (e) ->
#        libs.helper.getPositionOnLeaderboard(1, 'nobody', e.from, e.to, (err, result) ->
#          result.board.name.forEach( (name) -> libs.db.deliverMessage(name, e.mail) )
#        )
#      )
#  },
#  killMonsterPrize: {
#    time: { hour: 22 },
#    func: (libs) ->
#      cfg = [
#        {
#          from: 0,
#          to: 0,
#          mail: {
#            type: MESSAGE_TYPE_SystemReward,
#            src:  MESSAGE_REWARD_TYPE_SYSTEM,
#            prize: [{ type: 2, count: 50},
#                    { type: 0,value:866, count: 1}],
#            tit: "狩猎任务排行奖励",
#            txt: "恭喜你成为狩猎任务冠军，点击领取奖励。"
#          }
#        },
#        {
#          from: 1,
#          to: 4,
#          mail: {
#            type: MESSAGE_TYPE_SystemReward,
#            src:  MESSAGE_REWARD_TYPE_SYSTEM,
#            prize: [{ type: 2, count: 20},
#                    { type: 0,value:865, count: 1}],
#            tit: "狩猎任务排行奖励",
#            txt: "恭喜你进入狩猎任务前五，点击领取奖励。"
#          }
#        },
#        {
#          from: 5,
#          to: 9,
#          mail: {
#            type: MESSAGE_TYPE_SystemReward,
#            src:  MESSAGE_REWARD_TYPE_SYSTEM,
#            prize: [{ type: 2, count: 10},
#                    { type: 0,value:864, count: 1}],
#            tit: "狩猎任务排行奖励",
#            txt: "恭喜你进入狩猎任务前十，点击领取奖励。"
#          }
#        }
#      ]
#      cfg.forEach( (e) ->
#        libs.helper.getPositionOnLeaderboard(2, 'nobody', e.from, e.to, (err, result) ->
#          result.board.name.forEach( (name) -> libs.db.deliverMessage(name, e.mail) )
#        )
#      )
#  },
}

exports.splicePrize = (prize) ->
  goldPrize = { type: PRIZETYPE_GOLD, count: 0 }
  xpPrize = { type: PRIZETYPE_EXP, count: 0 }
  wxPrize = { type: PRIZETYPE_WXP, count: 0 }
  itemFlag = {}
  otherPrize = []
  prize.forEach( (p) ->
    return [] unless p?
    switch p.type
      when PRIZETYPE_WXP then wxPrize.count += p.count
      when PRIZETYPE_EXP then xpPrize.count += p.count
      when PRIZETYPE_GOLD then goldPrize.count += p.count
      when PRIZETYPE_ITEM
        if not itemFlag[p.value] then itemFlag[p.value] = 0
        itemFlag[p.value] += p.count
      else otherPrize.push(p)
  )
  for id, count of itemFlag
    otherPrize.push({ type: PRIZETYPE_ITEM, value: +id, count: + count})
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

# Observer
exports.observers = {
  heroxpChanged: (obj, arg) ->
    if arg.prevLevel isnt arg.currentLevel
      if arg.currentLevel is 10
        dbLib.broadcastEvent(BROADCAST_PLAYER_LEVEL, {
          who: obj.name,
          what: obj.hero.class
        })
}

exports.initObserveration = (obj) ->
  obj.observers = {}
  obj.installObserver = (event) -> obj.observers[event] = exports.observers[event]
  obj.removeObserver = (event) -> obj.observers[event] = null
  obj.notify = (event, arg) ->
    ob = obj.observers[event]
    if ob then ob(obj, arg)

exports.dbScripts = {
  getMercenary: """
  local battleforce, count, range = ARGV[1], ARGV[2], ARGV[3];
  local delta, rand, names, retrys = ARGV[4], ARGV[5], ARGV[6], ARGV[7];
  local table = 'Leaderboard.battleForce';

  local from = battleforce - range;
  local to = battleforce + range;

  while true
    local list = redis.call('zrevrange', table, from, to);
    local mercenarys = {}
    for i, v in ipairs(list) do
      ;
    end
    from = battleforce - range;
    to = battleforce + range;
    retrys -= 1;
    if retrys == 0 return {err='Fail'};
  end

  //doFindMercenary = (list, cb) ->
  //  if list.length <= 0
  //    cb(new Error('Empty mercenarylist'))
  //  else
  //    selector = selectRange(list)
  //    battleForce = selector[rand()%selector.length]
  //    list = list.filter((i) -> return i != battleForce; )
  //    mercenaryGet(battleForce, count, (err, mList) ->
  //      if mList == null
  //        dbClient.srem(mercenaryPrefix+'Keys', battleForce, callback)
  //        dbClient.del(mercenaryPrefix+battleForce)
  //        mList = []

  //      mList = mList.filter((key) ->
  //        for name in names
  //          if key is name then return false
  //        return true
  //      )
  //      if mList.length is 0
  //        cb(null, list)
  //      else
  //        selectedName = mList[rand()%mList.length]
  //        getPlayerHero(selectedName, (err, hero) ->
  //          if hero
  //            cb(new Error('Done'), hero)
  //          else
  //            logError({action: 'RemoveInvalidMercenary', error: err, name: selectedName})
  //            mercenaryDel(battleForce, selectedName, (err) -> cb(null, list))
  //        )
  //    )
  //actions = [ (cb) -> mercenaryKeyList(cb); ]
  //for i in [0..50]
  //  actions.push(doFindMercenary)
  //async.waterfall(actions, handler)

  """
}
