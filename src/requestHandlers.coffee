require('./define')
dbLib = require('./db')
dbWrapperLib = require('./dbWrapper')
async = require('async')
http = require('http')
moment = require('moment')

loginBy = (passportType, passport, token, callback) ->
  switch passportType
    when LOGIN_ACCOUNT_TYPE_91
      appID = '112988'
      appKey = 'd30d9f0f53e2654274505e25c27913fe709eb1ad6265e5c5'
      sign = md5Hash(appID+'4'+passport+token+appKey)
      path = 'http://service.sj.91.com/usercenter/AP.aspx?Act=4&AppId=112988&Uin='+passport+'&Sign='+sign+'&SessionID='+token
      http.get(path, (res) ->
        res.setEncoding('utf8')
        res.on('data', (chunk) ->
          result = JSON.parse(chunk)
          logInfo({action: 'login', type:  LOGIN_ACCOUNT_TYPE_91, code: result})
          if result.ErrorCode is '1'
            callback(null)
          else
            callback(Error(RET_LoginFailed))
        )
      ).on('error', (e) -> logError({action: 'login', type:  LOGIN_ACCOUNT_TYPE_91, error: e}))
    #when LOGIN_ACCOUNT_TYPE_KY
    when LOGIN_ACCOUNT_TYPE_PP
      options = {
        host: 'passport_i.25pp.com',
        port: 8080,
        method: 'POST',
        path: '/index?tunnel-command=2852126756',
        headers: { 'Content-Length': 32 }
      }
      req = http.request(options, (res) ->
        res.setEncoding('utf8')
        res.on('data', (chunk) ->
          result = JSON.parse('{'+chunk+'}')
          logInfo({action: 'login', type:  LOGIN_ACCOUNT_TYPE_PP, code: result.status})
          if result.status is 0
            callback(null)
          else
            callback(Error(RET_LoginFailed))
        )
      )
      req.on('error', (e) -> logError({action: 'login', type:  LOGIN_ACCOUNT_TYPE_PP, error: e}))
      req.write(token)
      req.end()
    when LOGIN_ACCOUNT_TYPE_TG
      dbLib.loadAuth(passport, token, callback)
    when LOGIN_ACCOUNT_TYPE_AD
      callback(null)
    else
      callback(Error(RET_Issue33))

loadPlayer = (passportType, passport, callback) ->
  async.waterfall([
    (cb)          -> dbLib.loadPassport(passportType, passport, true, cb),
    (account, cb) -> dbLib.loadAccount(account, cb),
    (account, cb) -> dbLib.loadPlayer(account[gServerName], cb)
  ], callback)

wrapReceipt = (name, serverID, time, productID, tunnel) -> name+'@'+serverID+'@'+time+'@'+productID+'@'+tunnel

exports.route = {
  RPC_ChargeDiamond: {
    id: 15,
    func: (arg, player, handle, rpcID, socket) ->
      switch arg.stp
        when 'AppStore' then throw Error('AppStore Payment')
        when 'PP25' then throw Error('PP25 Payment')
    ,
    args: ['pid', 'string', 'rep', 'string'],
    needPid: true
  },
  RPC_Login: {
    id: 100,
    func: (arg, dummy, handle, rpcID, socket, registerFlag) ->
      async.waterfall([
        (cb) ->
          if not arg.bv?
            cb(Error(RET_AppVersionNotMatch))
            logError({action: 'login', reason: 'noBinaryVersion'})
          else
            current = queryTable(TABLE_VERSION, 'bin_version')
            limit = queryTable(TABLE_VERSION, 'bin_version_need')
            unless limit <= arg.bv <= current
              cb(Error(RET_AppVersionNotMatch))
            else
              cb(null)
        ,
        (cb) -> if +arg.rv isnt queryTable(TABLE_VERSION, 'resource_version') then cb(Error(RET_ResourceVersionNotMatch)) else cb(null),
        (cb) -> if registerFlag then cb(null) else loginBy(arg.tp, arg.id, arg.tk, cb),
        (cb) -> loadPlayer(arg.tp, arg.id, cb),
        (player, cb) ->
          if player
            player.log('login', {type: arg.tp, id: arg.id})
            if socket
              player.socket = socket
              socket.player = player
              socket.playerName = player.name
            if gPlayerDB[player.name] then gPlayerDB[player.name].logout(RET_LoginByAnotherDevice)
            gPlayerDB[player.name] = player
            time = Math.floor((new Date()).valueOf() / 1000)
            ev = []
            player.updateMercenaryInfo(true)
            ev.push(player.notifyVersions())
            ev.push(player.syncEnergy())
            ev.push(player.syncFlags())
            if not player.abIndex?
              player.attrSave('abIndex', rand())
            ev.push({NTF: Event_ABIndex, arg: {ab: +player.abIndex}})
            ev.push({NTF: Event_UpdateStoreInfo, arg: gShop.dump(player)})
            ev.push({NTF: Event_PlayerInfo, arg: { vip: player.vipLevel(), rmb: player.rmb}})
            ev.push({NTF: Event_RoleUpdate, arg: { act: { vip: player.vipLevel()} } })
            async.parallel([
              (cb) -> player.fetchMessage(cb),
              (cb) -> player.updateFriendInfo(cb),
              (cb) -> dbLib.newSessionInfo((err, session) ->
                # TODO: accelerate this
                player.runtimeID = session
                dbLib.publish('login', JSON.stringify({player: player.name, session: session}))
                dbLib.updateSessionInfo(session, {player: player.name}, () ->)
                cb(null, [])
              )
            ], (err, result) ->
              result = result.reduce(((r, l) -> return r.concat(l);), [])
              ev = ev.concat(result).concat(player.onLogin()).concat(player.syncCampaign()).concat(player.syncEvent())
              loginInfo = {REQ: rpcID, RET: RET_OK, arg:{pid: player.runtimeID, rid: player.name, svt: time, usr: player.name, sid: gServerID}}
              if player.tutorialStage?  then loginInfo.arg.tut = player.tutorialStage
              handle([loginInfo].concat(ev))
              player.saveDB(cb)
            )
          else
            dbLib.newSessionInfo((err, session) ->
              if socket?
                socket.session = arg
                socket.session.sid = session
              dbLib.updateSessionInfo(session, arg, () ->)
              cb(Error(RET_AccountHaveNoHero))
            )
      ], (err, result) ->
        if err
          switch +err.message
            when RET_AppVersionNotMatch then ret = {arg: { url: queryTable(TABLE_VERSION, 'bin_url') }}
            when RET_ResourceVersionNotMatch then ret = {arg: { url: queryTable(TABLE_VERSION, 'url'), tar: queryTable(TABLE_VERSION, 'resource_version')}}
            when RET_AccountHaveNoHero then ret = {arg: {pid: socket.session.sid}}
            else ret = {}
          ret.REQ = rpcID
          ret.RET = +err.message
          handle([ret])
      )
    ,
    args: ['tp', 'number', 'id', 'string', 'bv', 'string', 'rv', 'number', 'ch', 'string']
  },
  RPC_Register: {
    id: 101,
    func: (arg, dummy, handle, rpcID, socket) ->
        #return handle([{REQ: rpcID, RET: RET_Issue38}]) unless socket?.pendingLogin?
      name = arg.nam
      async.waterfall([
        (cb) ->
          pendingLogin = socket.session
          cb(null, pendingLogin.tp, pendingLogin.id)
        ,
        (passportType, passport, cb) ->
          dbLib.loadPassport(passportType, passport, false, cb)
        ,
        #TODO: accelerate this
        (account, cb) -> dbLib.createNewPlayer(account, gServerName, name, cb),
        (player, cb) ->
          player.initialize()
          player.createHero({ name: name, class: arg.cid, gender: arg.gen, hairStyle: arg.hst, hairColor: arg.hcl })
          logUser({ name: name, action: 'register', class: arg.cid, gender: arg.gen, hairStyle: arg.hst, hairColor: arg.hcl })
          player.saveDB(cb)
      ], (err, result) ->
        if err
          handle([{REQ: rpcID, RET: +err.message}])
        else
          exports.route.RPC_Login.func(socket.session, dummy, handle, rpcID, socket, true)
      )
    ,
    args: ['pid', 'string', 'nam', 'string', 'cid', 'number', 'gen', 'number', 'hst', 'number', 'hcl', 'number']
  },
  RPC_ValidateName: {
    id: 102,
    func: (arg, dummy, handler, rpcID, socket) ->
      dbLib.validateName(arg.nam, (err) ->
        handler([{REQ: rpcID, RET : if err then +err.message else RET_OK}])
      )
    ,
    args: ['nam', 'string']
  },
  NTF_Echo: {
    id: 103,
    func: (arg, player, handler, rpcID, socket) ->
      evt = { NTF: Event_Echo, sign: arg.sign }
      if Number(arg.sign) >= 0
        evt.bv = queryTable(TABLE_VERSION, 'bin_version_need')
        evt.rv = queryTable(TABLE_VERSION, 'resource_version')
        evt.rvurl = queryTable(TABLE_VERSION, 'url')
        evt.bvurl = queryTable(TABLE_VERSION, 'bin_url')
      handler([evt])
    ,
    args: ['sign', 'number']
  },
  RPC_VerifyDungeon: {
    id: 17,
    func: (arg, player, handler, rpcID, socket) ->
      dungeonLib = require('./dungeon')
      result = {RET: RET_OK, REQ: rpcID}
      evt = [result]
      initialData = {}
      reward = []
      replay = []
      status = 'OK'
      fileList = ["define", "serializer", "spell", "unit", "container",
            "item", "seed-random", "commandStream", "dungeon", "trigger"]

      doVerify = () ->
        if player.dungeon
          for f in fileList
            if require('./'+f).fileVersion isnt arg.fileVersion[f]
              #logError({type:'fileVersion', file: f, version: arg.fileVersion[f], expect: require('./'+f).fileVersion})
              #result.RET = RET_Issue41
              status = 'FileVersionConflict'

          logInfo(player.dungeonData)
          initialData = player.dungeonData
          if result.RET is RET_OK and initialData?
            replay = arg.rep

            dungeon = new dungeonLib.Dungeon(initialData)
            dungeon.initialize()
            try
              dungeon.replayActionLog(replay)
            catch err
              status = 'Replay Failed'
              dungeon.reward = null
            finally
              reward = dungeon.reward
              if dungeon.stage is 0
                fakeReward = {
                  gold: 0, exp: 0, wxp: 0, reviveCount: 0, result: 2, prizegold: 0, prizexp: 0, prizewxp: 0, blueStar: 0, team: [], quests: { '0': { counters: [ 1 ] } }
                }
                rewardMsg = player.claimDungeonAward(fakeReward)
                evt = evt.concat(rewardMsg)
                status = 'Faked'
              else if reward
                rewardMsg = player.claimDungeonAward(reward)
                evt = evt.concat(rewardMsg)
              else
                status = 'Replay Failed'
                result.RET = RET_Unknown
                player.saveDB(() -> player.releaseDungeon())
        else
          status = 'No dungeon'
          result.RET = RET_DungeonNotExist

        logInfo({
          action : 'verify_dungeon',
          player : player.name,
          initial_data : initialData,
          reward : reward,
          replay : replay,
          status : status
        })

        handler(evt)

      if player.dungeon == null && player.dungeonID != -1
        player.loadDungeon(doVerify)
      else
        doVerify()
    ,
    args: [],
    needPid: true
  },
  Request_Stastics: {
    id: 28,
    func: (arg, player, handler, rpcID, socket) ->
      logInfo({action: 'stastics', key: arg.key, value: arg.val, name: player.name})
    ,
    args: [],
    needPid: true
  },
  RPC_GameStartDungeon: {
    id: 1,
    func: (arg, player, handler, rpcID, socket) ->
      player.startDungeon(+arg.stg, arg.initialDataOnly, (err, evEnter) ->
        if typeof evEnter is 'number'
          handler([{REQ: rpcID, RET: evEnter}])
        else if arg.initialDataOnly
          handler([{REQ: rpcID, RET: RET_OK, arg : evEnter}].concat(player.syncEnergy()))
        else if evEnter
          handler([{REQ: rpcID, RET: RET_OK}].concat(evEnter.concat(player.syncEnergy())))
        else
          handler([{REQ: rpcID, RET: RET_OK}])
        player.saveDB()
      )
    ,
    args: ['stg'],
    needPid: true
  },
  RPC_BindSubAuth: {
    func: (arg, player, handler, rpcID, socket) ->
      dbLib.bindAuth(player.accountID, arg.id, arg.pass, (err) ->
        if err
          handler([{REQ: rpcID, RET: err}])
        else
          handler([{REQ: rpcID, RET: RET_OK}])
      )
    ,
    args: [],
    needPid: true
  },
  RPC_Reconnect: {
    id: 104,
    args: ['pid', 'string'],
    func: (arg, player, handler, rpcID, socket) ->
      async.waterfall([
        (cbb) -> dbLib.loadSessionInfo(arg.PID, cbb),
        (sessionInfo, cbb) ->
          if not sessionInfo
            cbb(Error(RET_SessionOutOfDate))
          else
            socket.session = sessionInfo
            cbb(null, sessionInfo)
        ,
        (info, cbb) ->
          if info.bin_version isnt queryTable(TABLE_VERSION, 'bin_version') or
             +info.resource_version isnt +queryTable(TABLE_VERSION, 'resource_version')
               cbb(Error(RET_NewVersionArrived))
             else
               cbb( null, info )
        ,
        (session, cbb) ->
          if session.player
            dbLib.loadPlayer(session.player, cbb)
          else
            cbb(Error(RET_OK))
        ,
        (p, cbb) ->
          if not p or p.runtimeID isnt arg.PID
            cbb(Error(RET_SessionOutOfDate))
          else
            cbb(null, p)
        ,
        (p, cbb) ->
          p.onReconnect(socket)
          p.socket = socket
          socket.player = p
          socket.playerName = p.name
          gPlayerDB[p.name] = p
          p.updateFriendInfo(cbb)
        ],
        (err, result) ->
          if err and err.message isnt RET_OK
            handler([ {REQ: rpcID, RET: err.message} ])
          else
            handler([{REQ: rpcID, RET: RET_OK}])
        )
  },
  RPC_SubmitDailyQuest: {
    id: 29,
    func: (arg, player, handler, rpcID, socket) ->
      player.submitCampaign('event_daily', (err, ret) ->
        handler([{REQ: rpcID, RET: RET_OK}].concat(ret))
        player.saveDB()
      )
    ,
    args: [],
    needPid: true
  }
}
