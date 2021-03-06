"use strict"
require('./define')
dbLib = require('./db')
helperLib = require('./helper')
{DBWrapper, getPlayerHero, getPlayerArenaPrentices} = require './dbWrapper'
async = require('async')
http = require('http')
https = require('https')
querystring = require('querystring')
moment = require('moment')
underscore = require('./underscore')
{Player} = require('./player')

CONST_REWARD_PK_TIMES = 5

ReceivePrize_PK = 0
ReceivePrize_TimeLimit = 1

USE_ITEM_OPT_EQUIP = 1
USE_ITEM_OPT_ENHANCE = 2
USE_ITEM_OPT_LEVELUP = 3
USE_ITEM_OPT_CRAFT = 4
USE_ITEM_OPT_DECOMPOSE = 5
USE_ITEM_OPT_INJECTWXP = 6
USE_ITEM_OPT_RECYCLE = 7
# 分解装备
USE_ITEM_OPT_SELL = 8
UPGRAGE_SKILL = 9

PRENTICE_OP_CREATE = 0
PRENTICE_OP_REBORN = 1
PRENTICE_OP_UPGRADE = 2

CHALLENGECOIN_OP_GRAB = 0
checkRequest = (req, player, arg, rpcID, cb) ->
  dbLib.checkReceiptValidate(arg.rep, (isValidate) ->
    if isValidate
      req = https.request(req, (res) ->
        res.setEncoding('utf8')
        res.on('data', (chunk) ->
          result = JSON.parse(chunk)
          logInfo({action: 'VerifyPayment', type: 'Apple', code: result, receipt: arg.bill})
          if result.status isnt 0 or result.original_transaction_id
            return cb([{REQ: rpcID, RET: RET_InvalidPaymentInfo}])
          else
            receipt = arg.bill
            #receiptInfo = unwrapReceipt(result.transaction_id)
            #serverName = 'Master'
            player.handlePayment({
              paymentType: 'AppStore',
              productID: result.receipt.product_id,
              receipt: receipt,
            }, (err, result) ->
              dbLib.markReceiptInvalidate(arg.rep)
              ret = RET_OK
              ret = err.message if err?
              cb([{REQ: rpcID, RET: ret}].concat(result))
            )
        )
        .on('error', (e) ->
          logError({action: 'VerifyPayment', type: 'Apple', error: e, rep: arg.rep})
          cb([{REQ: rpcID, RET: RET_InvalidPaymentInfo}])
        )
      )
      req.write(JSON.stringify({"receipt-data": JSON.parse(arg.rep).receipt}))
      req.end()
    else
      cb([{REQ: rpcID, RET: RET_InvalidPaymentInfo}])
  )



loginBy = (arg, token, callback) ->
  passportType = arg.tp
  passport = arg.id
  switch passportType
    when LOGIN_ACCOUNT_TYPE_TB_IOS, LOGIN_ACCOUNT_TYPE_TB_Android
      switch passportType
        when LOGIN_ACCOUNT_TYPE_TB_IOS
          teebikURL = 'sdk.ios.teebik.com'
        when LOGIN_ACCOUNT_TYPE_TB_Android
          teebikURL = 'sdk.android.teebik.com'

      sign = md5Hash(token+ '|' +passport)
      requestObj = {
        uid : passport,
        token:token,
        sign : sign
      }

      path = 'http://'+teebikURL+'/check/user?'+ querystring.stringify(requestObj)
      http.get(path, (res) ->
        res.setEncoding('utf8')
        res.on('data', (chunk) ->
          result = JSON.parse(chunk)
          logInfo({action: 'login', type: passportType, code: result})
          if result.success is 1
            callback(null)
          else
            callback(Error(RET_LoginFailed))
        )
      ).on('error', (e) -> logError({action: 'login', type:  "LOGIN_ACCOUNT_TYPE_TB", error: e}))
    when LOGIN_ACCOUNT_TYPE_DK_Android
      appID = '3319334'
      appKey = 'kavpXwRFFa4rjcUy1idmAkph'
      AppSecret = 'KvCbUBBpAUvkKkC9844QEb8CB7pHnl5v'

      sign = md5Hash(appID+appKey+passport+token+AppSecret)
      path = 'http://sdk.m.duoku.com/openapi/sdk/checksession?appid='+appID+'&appkey='+appKey+'&uid='+passport+'&sessionid='+token+'&clientsecret='+sign
      http.get(path, (res) ->
        res.setEncoding('utf8')
        res.on('data', (chunk) ->
          result = JSON.parse(chunk)
          logInfo({action: 'login', type:  passportType, code: result})
          if result.error_code is '0'
            callback(null)
          else
            callback(Error(RET_LoginFailed))
        )
      ).on('error', (e) -> logError({action: 'login', type:  "LOGIN_ACCOUNT_TYPE_DK", error: e}))
    when LOGIN_ACCOUNT_TYPE_91_Android, LOGIN_ACCOUNT_TYPE_91_iOS
      switch passportType
        when LOGIN_ACCOUNT_TYPE_91_Android
          appID = '115411'
          appKey = '77bcc1c2b9cf260b12f124d1c280ae1de639b89e127842b1'
        when LOGIN_ACCOUNT_TYPE_91_iOS
          appID = '112988'
          appKey = 'd30d9f0f53e2654274505e25c27913fe709eb1ad6265e5c5'

      sign = md5Hash(appID+'4'+passport+token+appKey)
      path = 'http://service.sj.91.com/usercenter/AP.aspx?Act=4&AppId='+appID+'&Uin='+passport+'&Sign='+sign+'&SessionID='+token
      http.get(path, (res) ->
        res.setEncoding('utf8')
        res.on('data', (chunk) ->
          result = JSON.parse(chunk)
          logInfo({action: 'login', type: passportType, code: result})
          if result.ErrorCode is '1'
            callback(null)
          else
            callback(Error(RET_LoginFailed))
        )
      ).on('error', (e) -> logError({action: 'login', type:  "LOGIN_ACCOUNT_TYPE_91", error: e}))
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
      ).on('error', (e) -> logError({action: 'login', type:  "LOGIN_ACCOUNT_TYPE_KY", error: e}))
    when LOGIN_ACCOUNT_TYPE_PP
      appID = 2739
      appKey = '01aee5718a33bcbbe790bc0ca7cfb7ee'
      postBody = 
        'id': Math.round((new Date()).getTime()/1000)
        'service': 'account.verifySession'
        'game': 
          'gameId': appID
        'data': 
          'sid': token
        'encrypt': 'MD5'
        'sign': md5Hash('sid='+token+appKey)
      strBody = JSON.stringify(postBody)

      options = {
        host: 'passport_i.25pp.com',
        port: 8080,
        method: 'POST',
        path: '/account?tunnel-command=2852126760',
        headers: 
          'Content-Type': 'application/json'
          'Content-Length': strBody.length
      }
      req = http.request(options, (res) ->
        res.setEncoding('utf8')
        res.on('data', (chunk) ->
          result = JSON.parse(chunk)
          logInfo({action: 'login', type:  LOGIN_ACCOUNT_TYPE_PP, code: result.state})
          if result.state.code is 1
            #identifier = result.data.creator+result.data.accountId
            identifier = result.data.nickName
            callback(null, identifier)
          else
            callback(Error(RET_LoginFailed))
        )
      )
      req.on('error', (e) -> logError({action: 'login', type:  "LOGIN_ACCOUNT_TYPE_PP", error: e}))
      req.write(strBody)
      req.end()
    #when LOGIN_ACCOUNT_TYPE_TG
    #  dbLib.loadAuth(passport, token, callback)
    when LOGIN_ACCOUNT_TYPE_AD, LOGIN_ACCOUNT_TYPE_GAMECENTER, LOGIN_ACCOUNT_TYPE_Android
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
				#TODO:
				#(cb) ->
        #  if not arg.bv?
        #    cb(Error(RET_AppVersionNotMatch))
        #    logError({action: 'login', reason: 'noBinaryVersion'})
        #  else
        #    current = queryTable(TABLE_VERSION, 'bin_version')
        #    limit = queryTable(TABLE_VERSION, 'bin_version_need')
        #    unless limit <= arg.bv <= current
        #      cb(Error(RET_AppVersionNotMatch))
        #    else
        #      cb(null)
        #,
        #(cb) ->
        #  if +arg.rv isnt queryTable(TABLE_VERSION, 'resource_version')
        #    cb(Error(RET_ResourceVersionNotMatch))
        #  else cb(null)
        #,
        (cb) -> if registerFlag then cb(null) else loginBy(arg, arg.tk, cb),
        (identifier, cb) ->
          tp = arg.tp
          tp = arg.atp if arg.atp?
          id = arg.id
          if typeof(identifier) is 'function'
            loadPlayer(tp, id, identifier)
          else
            id = identifier
            arg.id = id
            loadPlayer(tp, id, cb)
        ,
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
            msg = {NTF: Event_PlayerInfo, arg: { aid: player.accountID, vip: player.vipLevel(), rmb: player.rmb}}
            if player.counters.monthCard
              msg.arg.mcc = player.counters.monthCard
            ev.push(msg)
            ev.push({NTF: Event_InventoryUpdateItem, arg:{god:player.gold, dim:player.diamond, mst:player.masterCoin}})
            ev.push(player.syncVipData())
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
              result = result.reduce(((r, l) -> return r.concat(l)), [])
              ev = ev.concat(result)
                     .concat(player.onLogin())
                     .concat(player.syncCampaign())
                     .concat(player.syncEvent())
              loginInfo = {REQ: rpcID, RET: RET_OK, arg:{pid: player.runtimeID, rid: player.name, svt: time, usr: player.name, sid: gServerID}}
              if player.tutorialStage? then loginInfo.arg.tut = player.tutorialStage
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
    args: {'tp':'number', 'id':'string', 'bv':'string', 'rv':'number', 'ch':'string'}
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
          player.createPlayer(arg, account, cb)
      ], (err, result) ->
        if err
          handle([{REQ: rpcID, RET: +err.message}])
        else
          exports.route.RPC_Login.func(socket.session, dummy, handle, rpcID, socket, true)
      )
    ,
    args: {'pid':'string', 'nam':'string', 'cid':'number', 'gen':'number', 'hst':'number', 'hcl':'number'}
  },
  RPC_SwitchHero: {
    id: 106,
    func: (arg, player, handler, rpcID, socket) ->
      type = player.switchHeroType(arg.cid)
      if player.flags[type]
        #player.flags[type] = false
        oldHero = player.hero
        player.createHero({
          name: oldHero.name
          class: arg.cid
          gender: oldHero.gender
          hairStyle: oldHero.hairStyle
          hairColor: oldHero.hairColor
          }, true)
        ret = [{REQ: rpcID, RET: RET_OK}]
        ret.concat(player.syncFlags(true))
      else
        ret = [{REQ: rpcID, RET: RET_NotEnoughItem}]
      handler(ret)
    ,
    args: {'cid':'number'}
  },
  RPC_ValidateName: {
    id: 102,
    func: (arg, dummy, handler, rpcID, socket) ->
      dbLib.validateName(arg.nam, (err) ->
        handler([{REQ: rpcID, RET : if err then +err.message else RET_OK}])
      )
    ,
    args: {'nam':'string'}
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

        evt.nv = queryTable(TABLE_VERSION, 'needed_version')
        evt.lv = queryTable(TABLE_VERSION, 'last_version')
        evt.sv = queryTable(TABLE_VERSION, 'suggest_version')
        evt.url = queryTable(TABLE_VERSION, 'url')
        if queryTable(TABLE_VERSION, 'branch')
          evt.br = queryTable(TABLE_VERSION, 'branch')
      handler([evt])
    ,
    args: {'sign':'string'}
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
            "item", "seed_random", "commandStream", "dungeon", "trigger"]

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

            logInfo('Creating Dungeon')
            dungeon = new dungeonLib.Dungeon(initialData)
            logInfo('Initializing Dungeon')
            dungeon.initialize()
            try
              logInfo('Replay Dungeon')
              dungeon.replayActionLog(replay)
            catch err
              status = 'Replay Failed'
              dungeon.result = DUNGEON_RESULT_FAIL
            finally
              logInfo('Claim Dungeon Award')
              evt = evt.concat(player.claimDungeonReward(dungeon))
              logInfo('Releasing Dungeon')
              player.releaseDungeon()
              logInfo('Saving')
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
    args: {},
    needPid: true
  },
  Request_Stastics: {
    id: 28,
    func: (arg, player, handler, rpcID, socket) ->
      logInfo({action: 'stastics', key: arg.key, value: arg.val, name: player.name})
    ,
    args: {},
    needPid: true
  },
  RPC_GameStartDungeon: {
    id: 1,
    func: (arg, player, handler, rpcID, socket) ->
      player.dungeonData = {}
      player.startDungeon(+arg.stg, arg.initialDataOnly, arg.tem, arg.pkr, arg.rank, (err, evEnter, extraMsg) ->
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
    args: {'stg':'number', 'initialDataOnly':'boolean', 'pkr':{type:'string',opt:true}, rank:{type:'string',opt:true}},
    needPid: true
  },
#  RPC_ChargeDiamond: {
#    id: 15,
#    func: (arg, player, handle, rpcID, socket) ->
#      switch arg.stp
#        when 'AppStore' then throw Error('AppStore Payment')
#        when 'PP25' then throw Error('PP25 Payment')
#    ,
#    args: {'pid':'string', 'rep':'string'},
#    needPid: true
#  },
#

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
          checkRequest(options, player,  arg, rpcID, (result) ->
            if result[0]?.RET is RET_InvalidPaymentInfo
              #try another
              options = {
                hostname: 'buy.itunes.apple.com',
                #hostname: 'sandbox.itunes.apple.com',
                port: 443,
                path: '/verifyReceipt',
                method: 'POST'
              }
              checkRequest(options, player, arg, rpcID,handler)
            else
              handler(result)
            )
    args: {},
    needPid: true
  },
  RPC_BindSubAuth: {
    id: 105,
    func: (arg, player, handler, rpcID, socket) ->
      if player?
        dbLib.bindAuth(player.accountID, arg.typ, arg.id, arg.pass, (err, account) ->
            handler([{REQ: rpcID, RET: RET_OK, aid: account}])
        )
      else
        handler([{REQ: rpcID, RET: RET_AccountHaveNoHero}])
    ,
    args: {}
  },
  RPC_Reconnect: {
    id: 104,
    args: {'PID':'number'},
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
      from = arg.src
      to = arg.src+arg.cnt-1
      switch arg.typ
        when helperLib.LeaderboardIdx.Revange, helperLib.LeaderboardIdx.ChallengeCoin
          gMiner.getPositionOnLeaderboard(arg.typ, player.name, from,to, (err, result) ->
            if err?
              logError({action: 'getRevengeLst', error: err})
              handler(new Error(RET_PlayerNotExists))
            else
              ret = {REQ: rpcID, RET: RET_OK}
              ret.lst = result
              handler([ret])
          )
        else
          helperLib.getPositionOnLeaderboard(arg.typ,
            player.name,
            from, to,
            (err, result) ->
              ret = {REQ: rpcID, RET: RET_OK}
              if arg.me? then ret.me = result.position
              if result.board?
                board = result.board
                async.map(board.name, getPlayerHero, (err, result) ->
                  ret.lst = result.map( (e, i) ->
                    return null unless e?
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
    args: {},
    needPid: true
  },
  RPC_MonthcardAward: {
    id: 31,
    func: (arg, player, handler, rpcID, socket) ->
      switch arg.bid
        when -1
          if player.counters.monthCard
            if player.counters.monthCard is 30
              ret = [{ NTF: Event_InventoryUpdateItem, arg: { dim : player.addDiamond(180) }}]
            else
              ret = [{ NTF: Event_InventoryUpdateItem, arg: { dim : player.addDiamond(80) }}]
            player.counters.monthCard--
            player.timestamp['monthCard'] = helperLib.currentTime()
            player.saveDB()
            handler([{REQ: rpcID, RET: RET_OK}].concat(ret))
    ,
    args: {},
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
    args: {},
    needPid: true
  },
  RPC_GetPkRivals: {
    id: 32,
    func: (arg, player, handler, rpcID, socket) ->
      dbLib.searchRival(player.name, (err, rivalLst) ->
        rivalLst = helperLib.warpRivalLst(rivalLst)
        ret = {REQ: rpcID, RET: RET_OK}
        async.map( rivalLst.name, getPlayerHero, (err, result) ->
          ret.arg = result.map( (e, i) ->
            return null unless e?
            r = getBasicInfo(e)
            r.rnk = +rivalLst.rnk[i]
            return r
          ).filter( (e) -> e?)
          #将玩家PK配置中的徒弟们也返回给客户端
          async.map(
            ret.arg,
            (basicHero, cb) ->
              getPlayerArenaPrentices(basicHero.nam, true, (err, prentices) ->
                basicHero.prt = prentices
                cb(err, basicHero)
              )
            ,
            (err, results) ->
              ret.arg = results
              handler([ret])
          )
        )
      )
    ,
    args: {},
    needPid: true
  },
  RPC_PVPInfoUpdate: {
    id: 34,
    func: (arg, player, handler, rpcID, socket) ->
      if arg.opn is 1
        if arg.lst?
          player.prenticeLst.setArenaLst(arg.lst)
          player.saveDB()
        ret = {REQ: rpcID, RET: RET_OK}
        handler(ret)
      else
        helperLib.getPositionOnLeaderboard(helperLib.LeaderboardIdx.Arena,
          player.name, 0 ,0, (err, result) ->
            ret = {REQ: rpcID, RET: RET_OK}
            ret.arg = {
              rnk: result.position
              cpl: player.counters.currentPKCount ? 0
              ttl: player.getTotalPkTimes()
              rcv: player.flags.rcvAward ? false
              tcd: player.getPkCoolDown()
              apc: player.getAddPkCount()
              prt: player.prenticeLst.getArenaLst()
            }
            handler(ret)
        )
    ,
    args: {},
    needPid: true
  },
  RPC_SweepStage: {
    id: 35,
    func: (arg, player, handler, rpcID, socket) ->
      { code, prize, ret } = player.sweepStage(+arg.stg, arg.mul, arg.rank)

      res = {REQ: rpcID, RET: code}
      if prize then res.arg = prize

      player.saveDB()

      handler([res].concat(ret))
    ,
    args: {},
    needPid: true
  },
  RPC_ReceivePrize: {
    id: 33,
    func: (arg, player, handler, rpcID, socket) ->
      switch arg.typ
        when ReceivePrize_PK
          if (not (player.counters.currentPKCount?) or CONST_REWARD_PK_TIMES > player.counters.currentPKCount or player.flags.rcvAward)

            handler([{REQ: rpcID, RET: RET_CantReceivePkAward}])
          else
            player.flags.rcvAward = true
            player.claimPkPrice((result) ->
              player.saveDB()
              handler([{REQ: rpcID, RET: RET_OK}].concat(result))
            )
        when ReceivePrize_TimeLimit
          {prize, sync}  = player.onCampaign('timeLimitAward')
          ret ={REQ:rpcID, RET:RET_RewardAlreadyReceived }
          if prize.length isnt 0
            ret.prize = prize
            ret.RET = RET_OK
          player.saveDB()
          handler([ret].concat(sync))
    ,
    args: {},
    needPid: true
  },
  RPC_WorldStageInfo: {
    id: 36,
    func: (arg, player, handler, rpcID, socket) ->
      helperLib.getPositionOnLeaderboard(
        helperLib.LeaderboardIdx.WorldBoss,
        player.name,
        0,
        0,
        (err, result) ->
          if result?
            times = gServerObject.counters['133']
            times ?= 0
            killTimes = player.counters['worldBoss']['133']
            killTimes ?= 0
            if killTimes is 0
              result.position = 9999

            ret = {REQ: rpcID, RET: RET_OK}
            ret.arg ={
              prg: {cpl: times, ttl:helperLib.ConstValue.WorldBossTimes},
              me:{cnt:+killTimes, rnk: +result.position}}
            handler(ret)
          else
            handler([{REQ: rpcID, RET: RET_GetLeaderboardInfoFailed}])
      )
    ,
    args: {},
    needPid: true
  },
  RPC_CommentGameInfo: {
    id: 37,
    func: (arg, player, handler, rpcID, socket) ->
      if arg.cmt?
        if player.flags.cmt?.cmted
          player.flags.cmt.auto = arg.cmt.auto
        else
          if player.flags.cmt?.cmted is false and arg.cmt.cmted is true
            player.quests?['183']?['counters'] = [1]
          player.flags['cmt'] = arg.cmt
      else
        player.flags.cmt = {cmted:false, auto: true} unless player.flags.cmt?
      player.save()
      ret = {REQ: rpcID, RET: RET_OK}
      ret.arg ={
        cmt:player.flags.cmt
      }
      handler(ret)
    ,
    args: {'cmt':{'cmted':'boolean', 'auto':'boolean'}},
    needPid: true
  },
  Request_LotteryFragment: {
    id: 38,
    func: (arg, player, handler, rpcID, socket) ->
      switch arg.cmd
        when 0 #cmd=0 抽奖 count抽奖次数 type使用表fragment的第type套奖品
          if arg.type?
            {prize, res, ret} = player.getFragment(arg.type, arg.count)
            player.saveDB()
            evt = {REQ: rpcID, RET: ret}
            evt.arg = prize
            if res? then handler([evt].concat(res))
            else handler([evt])
          else
            handler([{REQ: rpcID, RET: RET_NoParameter}])
        when 1 #cmd=1 获取免费抽奖CD时间
          if arg.type?
            handler({REQ: rpcID,RET:RET_OK, arg:{ fcd: player.getFragTimeCD(arg.type) }})
          else
            handler([{REQ: rpcID, RET: RET_NoParameter}])
    ,
    args: {'cmd':'number','type':'number'},
    needPid: true
  },
  Request_Redeem: {
    id: 40,
    func: (arg, player, handler, rpcID, socket) ->
      resMessage = []
      ret = {REQ: rpcID, RET: RET_RedeemFailed, arg:{}}
      if arg.code?
        #redeem

        if arg.code is player.invitation
          return handler(ret)

        async.waterfall(
          [
            (cb) -> helperLib.redeemCode.redeem(arg.code, cb),
            (config, cb) ->
              return cb("Redeemed Code") if config.redeemed is true
              switch Number(config.type)
                when CodeType_Prize
                  config.prize = JSON.parse(config.prize)
                  resMessage = player.claimPrize(config.prize)
                  ret.prize = config.prize
                  player.saveDB(cb)
                when CodeType_Invitation
                  if player.inviter or player.invitee[config.inviter]
                    return cb('Invite Each Other')
                  if arg.cfm is true
                    player.inviter = {}
                    player.inviter[config.inviter] = {tot: 0, cur: 0}
                    dbLib.deliverMessage(
                      config.inviter,
                      {
                        type: MESSAGE_TYPE_InvitationAccept,
                        name: player.name
                      }
                    )
                    player.saveDB(cb)
                  else
                    getPlayerHero(
                      config.inviter,
                      (err, hero) ->
                        if err
                          cb(err)
                        else
                          ret.arg.role = getBasicInfo(hero)
                          cb(null)
                    )
                    ret.arg.role = 0
          ],
          (err, res) ->
            logInfo({action: 'Redeem', code: arg.code, err: err})
            if err
              handler(ret)
            else
              ret.RET = RET_OK
              ret.RES = resMessage
              handler(ret)
        )
      else
        #send infomation
        ret.RET = RET_OK
        ret.arg = {}
        ret.arg.invitation = player.invitation
        handler(ret)
    ,
    args: {'code':'string'},
    needPid: true
  },
  Request_InvitationAward: {
    id: 41,
    func: (arg, player, handler, rpcID, socket) ->
      ret = {REQ: rpcID, RET: RET_RedeemFailed, arg:{}}
      switch Number(arg.opn)
        when 0 # get info
          ret.RET = RET_OK
          ret.arg = {}
          ret.arg.inviter = player.inviter
#          ret.arg.invitation = player.invitation
          ret.arg.invitee = player.invitee
          ret.arg.lst = []

          arr_inviteers = ({name:_name, tot:_data.tot, cur:_data.cur} for _name, _data of player.invitee)
          arr_inviteers.push({name:k1, tot:v1.tot, cur:v1.cur}) for k1, v1 of player.inviter

          sorted_arr_inviteers = underscore.sortBy(arr_inviteers, 'tot')
          sorted_arr_inviteers = underscore.sortBy(sorted_arr_inviteers, 'cur')
          sorted_arr_inviteers.reverse()

          from = arg.frm ? 0
          to = from + ( arg.cnt ? 10)
          sorted_arr_inviteers = sorted_arr_inviteers.slice(from, to)

          async.map(sorted_arr_inviteers,
            (invitee, cb) -> getPlayerHero(invitee.name, cb),
            (err, results) ->
              logInfo({action: 'getInvitationInfo', err: err})
              ret.arg.lst = results.map(getBasicInfo)
              handler(ret)
          )

        when 1 # receive award
          retInvAwa = {}
          async.waterfall([
            (cb) ->
              cb('name is null') unless arg.name
              retInvAwa = player.updateInvitationAward({name:arg.name, type:'receive'}, cb)
            ],
            (err, result) ->
              logInfo({action: 'ReceiveInvitationAward', source: arg.name, err: err})
              ret.RET = RET_OK
              ret.RES = retInvAwa.res
              ret.prize = retInvAwa.prize
              handler(ret)
          )

    ,
    args: {},
    needPid: true
  },
  ###########################################################################################
  SyncData:{
    id: 0,
    func: (arg, player, handler) ->
      ev = []
      #logWarn({ action : 'syncData', arg : arg });
      arg.forEach (e) ->
        if e == 'inv'
          ev.push player.syncBag(true)
        else if e == 'fog'
          ev = ev.concat(player.syncFurance(true))
        else if e == 'stg'
          ev = ev.concat(player.syncStage(true))
        else if e == 'act'
          ev = ev.concat(player.syncHero(true))
        else if e == 'dgn'
          ev = ev.concat(player.syncDungeon(true))
        else if e == 'eng'
          ev = ev.concat(player.syncEnergy(true))
        else if e == 'qst'
          ev = ev.concat(player.syncQuest(true))
        else if e == 'pre'
          ev = ev.concat(player.syncPrentice(true))
        #else if (e == 'frd') { ev = ev.concat(player.syncQuest(true)); }
        return
      handler(ev)
    needPid: true
  },
  QueryRoleInfo:{
    id: 26,
    func: (arg, player, handler, rpcID) ->
      dbWrapper.getPlayerHero(arg.nam, (err, hero) ->
        if hero
          handler([ {
            REQ: rpcID
            RET: RET_OK
            arg: getBasicInfo(hero)
          } ])
        else
          handler( [ {
            REQ: rpcID
            RET: RET_PlayerNotExists
          } ])
      )
    needPid: true
  },

  ExploreDungeon :{
    id: 2,
    func: (arg, player, handler, reqID, socket, flag, req) ->
      handler(player.dungeonAction(req))
      player.saveDB()
    needPid: true
  },

  DoActivate :{
    id: 3,
    func: (arg, player, handler, reqID, socket, flag, req) ->
      handler(player.dungeonAction(req))
      player.saveDB()
    needPid: true
  },

  DoAttack :{
    id: 4,
    func: (arg, player, handler, reqID, socket, flag, req) ->
      handler(player.dungeonAction(req))
      player.saveDB()
    needPid: true
  },

  DoSpell :{
    id: 5,
    func: (arg, player, handler, reqID, socket, flag, req) ->
      handler(player.dungeonAction(req))
      player.saveDB()
    needPid: true
  },

  DoCancelDungeon :{
    id: 20,
    func: (arg, player, handler, reqID, socket, flag, req) ->
      handler(player.dungeonAction(req))
      player.saveDB()
    needPid: true
  },

  DoCheckPos :{
    id: 39,
    func: (arg, player, handler, reqID, socket, flag, req) ->
      handler(player.dungeonAction(req))
      player.saveDB()
    needPid: true
  },

  DoRevive :{
    id: 8,
    func: (arg, player, handler, reqID, socket, flag, req) ->
      handler(player.dungeonAction(req))
      player.saveDB()
    needPid: true
  },

  DoCardSpell :{
    id: 6,
    func: (arg, player, handler, reqID, socket, flag, req) ->
      ret = player.dungeonAction(req)
      unless ret?
        ret = [ {
          NTF: Event_Fail
          msg: '_FIXME_Response_Invalid@' + 'handler_doCardSpell'
        } ]
      handler(ret)
      player.saveDB()
    needPid: true
  },

# 出售

  DoUseItem :{
    id: 7,
    func: (arg, player, handler, rpcID) ->
      slot = Math.floor(arg.sid)
      opn = Math.floor(arg.opn)
      pIdx = arg.pIdx
      ret = null
      switch opn
        when USE_ITEM_OPT_INJECTWXP
          ret = player.injectWXP(arg.opd, slot)
        when USE_ITEM_OPT_SELL
          ret = player.sellItem(slot, arg.sho)
        when USE_ITEM_OPT_LEVELUP
          ret = player.levelUpItem(slot, pIdx)
        when USE_ITEM_OPT_ENHANCE
          ret = player.enhanceItem(slot)
        when USE_ITEM_OPT_RECYCLE
          ret = player.recycleItem(slot)
        when USE_ITEM_OPT_DECOMPOSE
          ret = player.transformGem(arg.cid, arg.opc)
        when USE_ITEM_OPT_CRAFT
          ret = player.upgradeItemQuality(slot)
        when  UPGRAGE_SKILL
          skillId = slot
          ret = player.upgradeSkill(skillId)
        else
          ret = player.useItem(slot, opn, pIdx)
          break
      evt ={
        REQ: rpcID
        RET: RET_OK
      }
      evt.RET = ret.ret if ret.ret?
      evt.RES = ret.res if ret.res?
      evt.prz = ret.prize if ret.prize?
      evt.out = ret.out if ret.out?
      res = [ evt ]
      res = res.concat(ret.ntf) if ret.ntf?
      handler(res)
      player.saveDB()
    needPid: true
  },

  DoRequireMercenaryList :{
    id: 12,
    func: (arg, player, handler, rpcID) ->
      teamType = queryTable(TABLE_STAGE, arg.stg,player.abIndex).teamType
      player.mercenary = []
      player.requireMercenary((lst) ->
        if lst?
          handler([
            {
              REQ: rpcID
              RET: RET_OK
            },
            {
              NTF: Event_MercenaryList
              arg: lst.map(getBasicInfo)
            }
          ])
        else
          handler({
            REQ: rpcID
            RET: RET_RequireMercenaryFailed
          })
      ,teamType)
      player.saveDB()
    needPid: true
  },

  DoClaimLoginStreakReward :{
    id: 300,
    func: (arg, player, handler, rpcID) ->
      ret = player.claimLoginReward()
      res = [ {
        REQ: rpcID
        RET: ret.ret
      } ]
      if ret.res
        res = res.concat(ret.res)
      if ret.ret == RET_OK
        player.saveDB()
      handler(res)
    needPid: true
  },

# Request_RefreshRefreshMercenaryList

  DoRefreshMercenaryList :{
    id: 13,
    func: (arg, player, handler, rpcID) ->
      if player.addGold(RECRUIT_COST)
        player.log('refreshMercenaryList')
        player.replaceMercenary(arg.sid, (teammate) ->
          handler([
            {
              REQ: rpcID
              RET: RET_OK
              arg: getBasicInfo(teammate)
            }
            {
              NTF: Event_InventoryUpdateItem
              arg: god: player.gold
            }
          ]))
      else
        handler([ {
          REQ: rpcID
          RET: RET_NotEnoughGold
        } ])
      player.saveDB()
    needPid: true
  },

# Request_ClaimDungeonReward 

  DoCalimDungeonReward :{
    id: 11,
    func: (arg, player, handler) ->
      #var ret = player.claimDungeonAward();
      #handler(ret);
      player.saveDB()
    needPid: true
  },

  DoBuyItem :{
    id: 9,
    func: (arg, player, handler, rpcID) ->
      ret = gShop.sellProduct(arg.sid, arg.cnt, arg.ver, player)
      if typeof ret == 'number'
        handler([ {
          REQ: rpcID
          RET: ret
        } ])
      else
        handler([ {
          REQ: rpcID
          RET: RET_OK
        } ].concat(ret))
      player.saveDB()
    needPid: true
  },

  DoBuyEnergy :{
    id: 16,
    func: (arg, player, handler, rpcID) ->
      `var x`
      diamondCost = 0
      ENERGY_ADD = undefined
      switch +arg.typ
        when FEATURE_ENERGY_RECOVER
          if player.counters.energyRecover >= player.vipOperation('dayEnergyBuyTimes')
            handler new Error(RET_DungeonNotExist)
            return
          recoverTimes = player.counters.energyRecover
          ret = buyEnergyCost(recoverTimes, player.vipOperation('freeEnergyTimes'), player.vipOperation('energyPrize'))
          diamondCost = ret.prize
          ENERGY_ADD = ret.add
        when FEATURE_INVENTORY_STROAGE
          x = Math.floor((player.inventory.size() - 30) / 5)
          if x > 5
            x = 5
          diamondCost = 30 * x + 50
        when FEATURE_FRIEND_STROAGE
          x = Math.floor((player.contactBook.limit - 20) / 5)
          if x > 5
            x = 5
          diamondCost = 30 * x + 50
        when FEATURE_FRIEND_GOLD
          diamondCost = +arg.tar
        when FEATURE_PK_COOLDOWN
          diamondCost = 50
        when FEATURE_PK_COUNT
          diamondCost = 100
        when FEATURE_REVIVE
          if typeof player.dungeon == 'undefined' or player.dungeon == null
            handler new Error(RET_DungeonNotExist)
            return
          diamondCost = buyReviveCost(player.dungeon.revive, 0, player.vipOperation('reviveBasePrice'))
      evt = []
      product = ''
      if diamondCost and player.addDiamond(-Math.ceil(diamondCost)) != false
        evt.push
          REQ: rpcID
          RET: RET_OK
        if +arg.typ == FEATURE_ENERGY_RECOVER
          player.energy += ENERGY_ADD
          player.counters.energyRecover++
          product = 'energyTime'
          evt.push player.syncEnergy()
          evt.push player.syncCounters([ 'energyRecover' ])
          evt.push
            NTF: Event_InventoryUpdateItem
            arg: dim: player.diamond
        else if +arg.typ == FEATURE_INVENTORY_STROAGE
          product = 'inventory'
          evt.push
            NTF: Event_InventoryUpdateItem
            arg:
              cap: player.extendInventory(5)
              dim: player.diamond
        else if +arg.typ == FEATURE_FRIEND_STROAGE
          product = 'friend'
          player.contactBook.limit = +player.contactBook.limit + 5
          dbLib.extendFriendLimit player.name
          evt.push
            NTF: Event_FriendInfo
            arg: cap: player.contactBook.limit
          evt.push
            NTF: Event_InventoryUpdateItem
            arg: dim: player.diamond
        else if +arg.typ == FEATURE_FRIEND_GOLD
          player.addGold diamondCost * Rate_Gold_Diamond
          evt.push
            NTF: Event_InventoryUpdateItem
            arg:
              dim: player.diamond
              god: player.gold
        else if +arg.typ == FEATURE_PK_COOLDOWN
          player.clearCDTime()
          evt.push
            NTF: Event_InventoryUpdateItem
            arg: dim: player.diamond
        else if +arg.typ == FEATURE_PK_COUNT
          player.addPkCount 1
          evt.push
            NTF: Event_InventoryUpdateItem
            arg: dim: player.diamond
        else if +arg.typ == FEATURE_REVIVE
          ret = player.aquireItem(ItemId_RevivePotion, 1, true)
          if ret and ret.length > 0
            evt = evt.concat(ret.concat(
              NTF: Event_InventoryUpdateItem
              arg:
                god: player.gold
                dim: player.diamond))
          else
            player.addMoney p.price.type, cost
            evt = [ {
              REQ: rpcID
              RET: RET_NotEnoughDiamond
            } ]
        player.saveDB()
      else
        evt = [ {
          REQ: rpcID
          RET: RET_NotEnoughDiamond
        } ]
      logUser
        name: player.name
        action: 'buy'
        product: product
        payMethod: 'diamond'
        item: product
        cost: diamondCost
      handler evt
      return
    needPid: true
  },

  DoClaimQuestReward :{
    id: 18,
    func: (arg, player, handler, rpcID) ->
      ret = player.claimQuest(arg.qid)
      if typeof ret == 'number'
        handler [ {
          REQ: rpcID
          RET: ret
        } ]
      else
        handler [ {
          REQ: rpcID
          RET: RET_OK
        } ].concat(ret)
      player.saveDB()
    needPid: true
  },

  DoUpdateTutorial :{
    id: 27,
    func: (arg, player, handler, rpcID) ->
      player.log 'updateTutorial', tutorial: arg.stg
      player.tutorialStage = +arg.stg
      player.saveDB()
    needPid: true
  },

  DoChat :{
    id: 19,
    func: (arg, player, handler, rpcID) ->
      dbLib.broadcast
        NTF: Event_ChatInfo
        arg:
          src: player.name
          typ: CHAT_TYPE_PLAYER
          txt: arg.txt
          vip: player.vipLevel()
          cla: player.hero.class
          pow: player.battleForce
      logUser
        name: player.name
        action: 'chat'
        type: 'global'
        text: arg.txt
      #TODO:聊天信息间隔
      handler
        REQ: rpcID
        RET: RET_OK
    needPid: true
  },

  DoInviteFriend :{
    id: 21,
    func: (arg, player, handler, rpcID) ->
      player.inviteFriend arg.nam, arg.id, (err, ret) ->
        handler
          REQ: rpcID
          RET: err.message
        return
      return
    needPid: true
  },

  DoRemoveFriend :{
    id: 22,
    func: (arg, player, handler, rpcID) ->
      handler
        REQ: rpcID
        RET: player.removeFriend(arg.nam)
      return
    needPid: true
  },

  DoHireFriend :{
    id: 23,
    func: (arg, player, handler, rpcID) ->
      player.hireFriend arg.nam, (lst) ->
        if Array.isArray(lst)
          handler [
            {
              REQ: rpcID
              RET: RET_OK
            }
            {
              NTF: Event_MercenaryList
              arg: lst.map(getBasicInfo)
            }
          ]
        else
          handler
            REQ: rpcID
            RET: RET_HireFriendFailed
        return
      return
    needPid: true
  },

  DoWhisper :{
    id: 24,
    func: (arg, player, handler, rpcID) ->
      player.whisper arg.nam, arg.txt, (err, ret) ->
        if err == null
          err = RET_OK
        handler
          REQ: rpcID
          RET: err
        return
      return
    needPid: true
  },

  DoOperateNotify :{
    id: 25,
    func: (arg, player, handler, rpcID) ->
      player.operateMessage arg.typ, arg.sid, arg.opn, (err, ret) ->
        if err == null
          err = RET_OK
        if ret
          ret = [ {
            REQ: rpcID
            RET: err
          } ].concat(ret)
        else
          ret = [ {
            REQ: rpcID
            RET: err
          } ]
        handler ret
        player.saveDB()
        return
      return
    needPid: true
  },
  Request_Shops : {
    id:42,
    func: (arg, player, handler, rpcID, socket) ->
      ret = {REQ: rpcID, RET: RET_GetInfoFailed, arg:{}}
      switch Number(arg.opn)
        when 0 # check version / get info
          shop = player.getShop(arg.name) ? {}
          return handler(ret) if shop.err?
          if (not arg.ver?) or (arg.ver isnt shop.version)
            ret.arg.shop = shop.dump2()
          ret.RET = RET_OK
          handler(ret)
        when 1 # purchase
          shop = player.getShop(arg.name) ? {}
          return handler(ret) if shop.err?
          sell_rst = shop.sell(player, arg.idx, arg.cnt, arg.ver)
          if sell_rst.error?
            logError({action: 'Shop.sell', error: sell_rst.error})
            ret.RET = RET_PurchaseFailed
            handler(ret)
          else
            ret.RET = RET_OK
            if sell_rst.version?
              ret.arg.shop = shop.dump2()
            player.saveDB()
            handler([ret].concat(sell_rst.ret))
        when 2 # consume diamond to refresh
          shop = player.getShop(arg.name, true) ? {}
          return handler(ret) if shop.err?
          ret.arg.shop = shop.dump2()
          ret.RET = RET_OK
          handler([ret].concat(
            {NTF: Event_InventoryUpdateItem, arg:{god:player.gold, dim:player.diamond, mst:player.masterCoin}}
          ))
        else # miss opn
          handler(ret)
    args: {},
    needPid: true
  },
  PrenticeOpt:{
    id: 43,
    func: (arg, player, handler, rpcID) ->
      switch arg.opn
        when PRENTICE_OP_CREATE
          {ret,ntf} = player.prenticeLst.add(arg)
        when  PRENTICE_OP_REBORN
          {ret,ntf} = player.prenticeLst.add(arg,arg.pIdx)
        when PRENTICE_OP_UPGRADE
          {ret,ntf} = player.prenticeLst.upgrade(arg.pIdx)
      result = [{RET: ret, REQ: rpcID}]
      result = result.concat(ntf) if ntf?
      handler(result)
      player.saveDB()
    needPid: true
  },
  ChallengeCoinOpt:{
    id: 44,
    func: (arg, player, handler, rpcID) ->
      switch arg.opn
        when CHALLENGECOIN_OP_GRAB #grab
          {ret, ntf,cnt} = gMiner.grab(player)
        when 1 # test rob
          {ret, ntf} = gMiner.rob(arg.nam, player,2)
        when 2 #debug print
          gMiner.print()
      result = [{RET: ret, REQ: rpcID,max:player.getMaxChallengeCoin()}]
      result[0].cnt = cnt if cnt?
      result = result.concat(ntf) if ntf?
      handler(result)
      player.saveDB()
    needPid: true
  },
  RPC_LineUp:{
    id: 999, #todo:
    func: (arg, player, handler, rpcID) ->
      ret = {REQ: rpcID, RET:RET_Issue41, arg:{}}
      switch Number(arg.opn)
        when 0 #get
          ret.arg.lin = player.lineUps
          ret.RET = RET_OK
        when 1 #set
          if arg.lin and Array.isArray(arg.lin)
            for l in arg.lin
              if not Array.isArray(l) then l = []
            player.lineUps = arg.lin
            player.saveDB()
            ret.RET = RET_OK
      handler(ret)
    ,
    needPid: true
  }
}
