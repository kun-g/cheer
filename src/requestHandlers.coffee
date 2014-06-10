require('./define')
dbLib = require('./db')
helperLib = require('./helper')
{DBWrapper, getMercenaryMember, updateMercenaryMember, addMercenaryMember, getPlayerHero} = require './dbWrapper'
async = require('async')
http = require('http')
https = require('https')
moment = require('moment')
{Player} = require('./player')

loginBy = (arg, token, callback) ->
  passportType = arg.tp
  passport = arg.id
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
    when LOGIN_ACCOUNT_TYPE_KY
      appID = '4032'
      appKey = '42e50a13d86cda48be215d3f64856cd3'
      sign = md5Hash(appKey+token)
      path = 'http://f_signin.bppstore.com/loginCheck.php?tokenKey='+token+'&sign='+sign
      http.get(path, (res) ->
        res.setEncoding('utf8')
        res.on('data', (chunk) ->
          result = JSON.parse(chunk)
          logInfo({action: 'login', type:  LOGIN_ACCOUNT_TYPE_KY, code: result})
          if result.code is 0
            arg.id = result.data.guid
            callback(null)
          else
            callback(Error(RET_LoginFailed))
        )
      ).on('error', (e) -> logError({action: 'login', type:  LOGIN_ACCOUNT_TYPE_91, error: e}))
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
    #when LOGIN_ACCOUNT_TYPE_TG
    #  dbLib.loadAuth(passport, token, callback)
    when LOGIN_ACCOUNT_TYPE_AD, LOGIN_ACCOUNT_TYPE_GAMECENTER
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
        (cb) -> if registerFlag then cb(null) else loginBy(arg, arg.tk, cb),
        (cb) -> loadPlayer(arg.tp, arg.id, cb),
        (player, cb) ->
          if player
            player.log('login', {type: arg.tp, id: arg.id})
            if socket
              player.socket = socket
              socket.player = player
              socket.playerName = player.name
            if gPlayerDB[player.name]
              gPlayerDB[player.name].logout(RET_LoginByAnotherDevice)
              delete gPlayerDB[player.name]
            gPlayerDB[player.name] = player
            time = Math.floor((new Date()).valueOf() / 1000)
            ev = []
            player.updateMercenaryInfo(true)
            ev.push(player.notifyVersions())
            ev.push(player.syncEnergy())
            ev.push(player.syncFlags())
            ev.push({NTF: Event_ABIndex, arg: {ab: +player.abIndex}})
            ev.push({NTF: Event_UpdateStoreInfo, arg: gShop.dump(player)})
            ev.push({NTF: Event_PlayerInfo, arg: { aid: player.accountID, vip: player.vipLevel(), rmb: player.rmb}})
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
              if player.destroied then return []
              result = result.reduce(((r, l) -> return r.concat(l);), [])
              ev = ev.concat(result)
                     .concat(player.onLogin())
                     .concat(player.syncCampaign())
                     .concat(player.syncEvent())
              loginInfo = {REQ: rpcID, RET: RET_OK, arg:{pid: player.runtimeID, rid: player.name, svt: time, usr: player.name, sid: gServerID}}
              if player.tutorialStage?  then loginInfo.arg.tut = player.tutorialStage
              handle([loginInfo].concat(ev))
              player.saveDB(cb)
              player = null
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
        (account, cb) ->
          player = new Player()
          player.setName(name)
          player.accountID = account
          player.initialize()
          player.createHero({ name: name, class: arg.cid, gender: arg.gen, hairStyle: arg.hst, hairColor: arg.hcl })
          prize = queryTable(TABLE_CONFIG, 'InitialEquipment')
          for k, p of prize
            player.claimPrize(p.filter((e) => isClassMatch(arg.cid, e.classLimit)))
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
              dungeon.result = DUNGEON_RESULT_FAIL
            finally
              evt = evt.concat(player.claimDungeonAward(dungeon))
              player.releaseDungeon()
              player.saveDB()
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
      player.dungeonData = {}
      player.startDungeon(+arg.stg, arg.initialDataOnly, (err, evEnter, extraMsg) ->
        extraMsg = (extraMsg ? []).concat(player.syncEnergy())
        if typeof evEnter is 'number'
          handler([{REQ: rpcID, RET: evEnter}].concat(extraMsg))
        else if arg.initialDataOnly
          handler([{REQ: rpcID, RET: RET_OK, arg : evEnter}].concat(extraMsg))
        else if evEnter
          handler([{REQ: rpcID, RET: RET_OK}].concat(evEnter.concat(extraMsg)))
        else
          handler([{REQ: rpcID, RET: RET_OK}].concat(extraMsg))
        player.saveDB()
      )
    ,
    args: ['stg'],
    needPid: true
  },
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
  RPC_VerifyPayment: {
    id: 15,
    func: (arg, player, handler, rpcID, socket) ->
      logInfo({action: 'VerifyPayment', type: 'Apple', arg: arg})
      switch arg.stp
        when 'AppStore'
          options = {
            #hostname: 'buy.itunes.apple.com',
            hostname: 'sandbox.itunes.apple.com',
            port: 443,
            path: '/verifyReceipt',
            method: 'POST'
          }
          req = https.request(options, (res) ->
            res.setEncoding('utf8')
            res.on('data', (chunk) ->
              result = JSON.parse(chunk)
              logInfo({action: 'VerifyPayment', type: 'Apple', code: result, receipt: arg.bill})
              if result.status isnt 0 or result.original_transaction_id
                return handler([{REQ: rpcID, RET: RET_Unknown}])

              receipt = arg.bill
              #receiptInfo = unwrapReceipt(result.transaction_id)
              #serverName = 'Master'
              player.handlePayment({
                paymentType: 'AppStore',
                productID: result.product_id,
                receipt: receipt
              }, (err, result) ->
                ret = RET_OK
                ret = err.message if err?
                handler([{REQ: rpcID, RET: ret}].concat(result))
              )
            )
          )
          .on('error', (e) ->
            logError({action: 'VerifyPayment', type: 'Apple', error: e, rep: arg.rep})
            handler([{REQ: rpcID, RET: RET_InvalidPaymentInfo}])
          )

          req.write(JSON.stringify({"receipt-data": arg.rep}))
          req.end()
    args: [],
    needPid: true
  },
  RPC_BindSubAuth: {
    id: 105,
    func: (arg, player, handler, rpcID, socket) ->
      account = -1
      if player then account = player.accountID
      dbLib.bindAuth(account, arg.typ, arg.id, arg.pass, (err, account) ->
        handler([{REQ: rpcID, RET: RET_OK, aid: account}])
      )
    ,
    args: []
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
  RPC_QueryLeaderboard: {
    id: 30,
    func: (arg, player, handler, rpcID, socket) ->
      helperLib.getPositionOnLeaderboard(arg.typ,
        player.name,
        arg.src,
        arg.src+arg.cnt-1,
        (err, result) ->
          ret = {REQ: rpcID, RET: RET_OK}
          if arg.me? then ret.me = result.position
          if result.board?
            board = result.board.reduce( ( (r, l, i) ->
              if i%2 is 0
                r.name.push(l)
              else
                r.score.push(l)
              return r
            ), {name: [], score: []})
            async.map(board.name, getPlayerHero, (err, result) ->
              ret.lst = result.map( (e, i) ->
                r = getBasicInfo(e)
                r.scr = +board.score[i]
                return r
              )
              handler([ret])
            )
          else
            handler([ret])
      )
    ,
    args: [],
    needPid: true
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
