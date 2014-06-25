require("./define");
var async = require('async');
var redis = require("redis");

//////////////////////////////// 
//DB
makeDBKey = function (keys) {
  ret = keys[0];
  for (var k = 1; k < keys.length; k++) {
    var key = keys[k];
    ret += dbSeparator+key;
  }
  return ret;
};
//////////////// Account Operation ////////////////
exports.verifyAuth = function (id, token, handler) {
  accountDBClient.hgetall(makeDBKey([authPrefix, id]), function (err, auth) {
    if (auth && md5Hash(auth.salt+token) == auth.pass) {
      handler(null);
    } else {
      handler(Error(RET_LoginFailed));
    }
  });
};
exports.bindAuth = function (account, type, id, pass, handler) {
  //var acc = { account: account };
  //if (pass) {
  //  acc.salt = Math.random();
  //  acc.pass = md5Hash(acc.salt+pass);
  //}
  var key = makeDBKey([passportPrefix, type, id, 'account']);
  accountDBClient.get(key, function (err, acc) {
    if (acc != null) {
      handler(null, acc);
    } else if (acc != -1) {
      accountDBClient.set(key, account, function () { handler(null, account); });
    } else {
     handler(null, account);
    }
  });
};

exports.loadPassport = function (type, id, createOnFail, handler) {
  accountDBClient.get(makeDBKey([passportPrefix, type, id, 'account']), function (err, ret) {
    if (ret) {
      handler(err, ret);
    } else if (err) {
      logError({action: 'LoadPassport', error:err, type: type, id: id});
    } else if (createOnFail) {
      createPassportWithAccount(type, id, handler);
    } else {
      handler(err, ret);
    }
  });
};

exports.loadAccount = function (id, handler) { accountDBClient.hgetall(makeDBKey([accPrefix, id]), handler); };
exports.getPlayerNameByID = function (id, serverName, cb)  { accountDBClient.hget(makeDBKey([accPrefix, id]), serverName, cb); };
// TODO: creation after creation
exports.updateAccount = function (id, key, val, cb){ accountDBClient.hset(makeDBKey([accPrefix, id]), key, val, cb); };
//////////////// Player Creation ////////////////

function createNewPlayer (account, server, name, handle) {
  async.series([
      function (cb) { nameValidation(name, cb); },
      function (cb) { doCreateNewPlayer(account, dbPrefix, name, cb); },
      function (cb) {
        if (account != null) {
          exports.updateAccount(account, server, name, cb);
        } else {
          cb(null);
        }
      }
    ], function (err, result) {
      handle(err, account);
    });
}
exports.createNewPlayer = createNewPlayer;

exports.loadSessionInfo = function (session, handler) {
  dbClient.hgetall(makeDBKey([sessionPrefix, session]), handler);
};

lua_createPassportWithAccount = " \
  local type, id, date = ARGV[1], ARGV[2], ARGV[3]; \
  local key = 'Passport.'..type..'.'..id..'.account'; \
  if redis.call('EXISTS', key)==1 then \
    return {err='PassportExists'}; \
  else \
    local uid = redis.call('INCR', 'CurrentUID'); \
    redis.call('set', key, uid); \
    redis.call('hset', 'Account.'..uid, 'create_date', date); \
    return uid; \
  end";

lua_createNewPlayer = " \
  local prefix, name, account = ARGV[1], ARGV[2], ARGV[3]; \
  local PlayerNameSet = prefix..'UsedName'; \
  local key = prefix..'player.'..name; \
  local limitsKey = prefix..'limits.'..name; \
  local sharedKey = prefix..'shared.'..name; \
  if redis.call('sadd', PlayerNameSet, name)==0 then \
    return 'NameTaken'; \
  else \
    local x = redis.call('hmset', key, 'accountID', account, 'name', name, 'isNewPlayer', 'true'); \
    local y = redis.call('hset', limitsKey, 'blueStar', 8); \
    local z = redis.call('hmset', sharedKey, 'blueStar', 0, 'contactLimit', 20); \
    return account; \
  end";

lua_createSessionInfo = " \
  local prefix, date, bv, rv = ARGV[1], ARGV[2], ARGV[3], ARGV[4]; \
  local id = redis.call('INCR', 'SessionCounter'); \
  local key = prefix..'Session.'..id; \
  redis.call('hmset', key, 'create_date', date, 'sid', id, \
      'bin_version', bv, 'resource_version', rv); \
  redis.call('expire', key, 36000); \
  return id;";

lua_queryLeaderboard = " \
  local prefix = 'Leaderboard.'; \
  local board, name, from, to = ARGV[1], ARGV[2], ARGV[3], ARGV[4]; \
  local key = prefix..board; \
  local rank = redis.call('ZREVRANK', key, name); \
  local board = redis.call('zrevrange', key, from, to, 'WITHSCORES'); \
  return {rank, board};";

var lua_fetchMessage = " \
  local dbPrefix, name = ARGV[1], ARGV[2]; \
  local messagePrefix = dbPrefix..'message.'; \
  local playerMessage = dbPrefix..'playerMessage.'..name; \
  local list = redis.call('SMEMBERS', playerMessage); \
  local result = {}; \
  local reward = {}; \
  for i, v in ipairs(list) do \
    local msg = redis.call('get', messagePrefix..v); \
    if msg then \
      msg = cjson.decode(msg); \
      if msg.type == 201 and msg.src == 0 then \
        reward[#reward+1] = msg; \
      else \
        result[#result+1] = msg; \
      end \
    else \
      redis.call('srem', playerMessage, v); \
    end \
  end \
  if #reward > 0 then \
    local msg = reward[1]; \
    if #reward > 1 then \
      local tmp = { exp=0, wxp=0, gold=0, diamond=0 }; \
      for _, p in ipairs(reward) do \
        for _, v in ipairs(p.prize) do \
          if v.type == 1 then tmp.gold = tmp.gold+v.count; end \
          if v.type == 2 then tmp.diamond = tmp.diamond+v.count; end \
          if v.type == 3 then tmp.exp = tmp.exp+v.count; end \
          if v.type == 4 then tmp.wxp = tmp.wxp+v.count; end \
        end \
        redis.call('srem', playerMessage, p.messageID); \
        redis.call('del', messagePrefix..p.messageID); \
      end \
      local tmpPrize = {}; \
      if tmp.gold>0 then table.insert(tmpPrize, {type=1, count=tmp.gold}); end\
      if tmp.diamond>0 then table.insert(tmpPrize, {type=2, count=tmp.diamond}); end\
      if tmp.exp>0 then table.insert(tmpPrize, {type=3, count=tmp.exp}); end\
      if tmp.wxp>0 then table.insert(tmpPrize, {type=4, count=tmp.wxp}); end\
      local msgID = redis.call('INCR', dbPrefix..'message.MessageID'); \
      msg = {type=201, messageID=msgID, src=0, prize=tmpPrize}; \
      redis.call('SADD', playerMessage, msgID); \
      redis.call('SET', messagePrefix..msgID, cjson.encode(msg)); \
    end \
    result[#result+1] = msg; \
  end \
  if #result > 0 then \
    return cjson.encode(result); \
  else \
    return '[]'; \
  end";

var lua_searchRival =" \
  local randLst ={ ARGV[3], ARGV[4], ARGV[5] } \
  local prefix = 'Leaderboard.'; \
  local board, name = ARGV[1], ARGV[2]; \
  local config ={{base=0.95,delt=0.02}, \
    {base=0.85,delt=0.03}, \
    {base=0.50,delt=0.05}}; \
  if randLst[3] == nil then \
    return nil \
  end \
  local key = prefix..board; \
  local rank = redis.call('ZREVRANK', key, name); \
  local rivalLst ={} ; \
  for i,scope in ipairs(config) do \
    local from = math.floor(rank * (scope.base - scope.delt + scope.delt *(2*randLst[i]))); \
    rivalLst[i] = redis.call('zrange', key, from, from, 'WITHSCORES'); \ \
  end \
  return rivalLst;";

var lua_exchangeScore = " \
  local board, champion, second = ARGV[1], ARGV[2], ARGV[3]; \
  local prefix = 'Leaderboard.'; \
  local key = prefix..board; \
  local championRank = redis.call('ZRANK', key, champion); \
  local secondRank = redis.call('ZRANK', key, second); \
  if championRank < secondRank then \
    redis.call('ZADD',key,second, championRank); \
    redis.call('ZADD',key,champion, secondRank); \
    return {championRank,secondRank} ; \
  end \
  return 'noNeed'; ";

var lua_getPvpInfo = " \
  local board, name = ARGV[1],ARGV[2]; \
  local prefix = 'Leaderboard.'; \
  local key = prefix..board; \
  local rank = redis.call('ZREVRANK', key, name); \
  return 'noFinished'; ";
exports.updateSessionInfo = function (session, obj, handler) {
  dbClient.hmset(makeDBKey([sessionPrefix, session]), obj, handler);
};

function playerExistenceCheck (name, handle) {
  dbClient.sismember(PlayerNameSet, name, function (err, ret) {
    if (err == null && ret === 0) {
      err = new Error(RET_PlayerNotExists);
    }
    handle(err);
  });
}
exports.playerExistenceCheck =  playerExistenceCheck;

function nameValidation (name, handle) {
  if (!isNameValid(name)) {
    handle(new Error(RET_InvalidName));
  } else {
    handle(null);
  }
}

exports.validateName = function (name, handle) {
  async.series([
      function (cb) { nameValidation(name, cb); },
      function (cb) { dbClient.sismember(PlayerNameSet, name, function (err, ret) {
          if (+ret == 1) {
            cb (new Error(RET_NameTaken));
          } else {
            cb (null);
          }
        });
      }], handle);
};

function removePlayer (name, handle) {
  async.series([
      function (cb) { dbClient.del(playerPrefix+name, cb); },
      function (cb) { dbClient.del(sharedPrefix+name, cb); },
      function (cb) { dbClient.del(friendPrefix+name, cb); },
      function (cb) { dbClient.del(dungeonPrefix+name, cb); },
      function (cb) { dbClient.del(limitsPrefix+name, cb); },
      function (cb) { dbClient.del(playerMessagePrefix+name, cb); },
      function (cb) { dbClient.srem(PlayerNameSet, name, cb); }
    ],
    function (err, results) {
      if (handle) handle(err);
    });
}
exports.removePlayer = removePlayer;

function tryToRegisterName (name, callback) {
  dbClient.sadd(PlayerNameSet, name, function (err, ret) {
    if (err == null && ret == 0) err = new Error(RET_NameTaken);
    callback(err);
  });
}

function loadPlayer(name, handler) {
  var dbKeyName = playerPrefix+name;
  dbClient.hgetall(dbKeyName, function (err, result) {
    var p = null;
    if (result) {
      var attributes = {};
      for (var k in result) {
        var v = result[k];
        try {
          attributes[k] = JSON.parse(v);
        } catch (error) {
          attributes[k] = v;
        }
      }
      var playerLib = require('./player');
      p = new playerLib.Player(attributes);
      p.initialize();
    }
    if (handler) handler(err, p);
    p = null;
  });
}

exports.loadPlayer = loadPlayer;
 
////////////// Player Manipulation //////////////
function incrBluestarBy (name, point, handler) {
  async.parallel([
        function (cb) { dbClient.hincrby(sharedPrefix+name, 'blueStar', point, cb); },
        function (cb) { dbClient.hget(limitsPrefix+name, 'blueStar', cb); }
      ], function (err, result) {
        var pt = result[0];
        var limit = result[1];
        if (pt > limit) {
          incrBluestarBy(name, limit-pt, handler);
        } else {
          if (handler) handler(err);
        }
      });
}
exports.incrBluestarBy = incrBluestarBy;

function deliverMessage(name, message, callback, serverName) {
  var prefix = messagePrefix;
  if (serverName) { prefix = serverName+dbSeparator+'message'+dbSeparator; }
  dbClient.incr(prefix+'MessageID', function (err, r) {
    message.messageID = r;
    async.parallel([
        function (cb) { dbClient.sadd(playerMessagePrefix+name, r, cb); },
        function (cb) { dbClient.set(messagePrefix+r, JSON.stringify(message), cb); }
      ],
      function (err, result) {
        publishPlayerChannel(name, 'New Message');
        if (callback) callback(err, r);
      });
  });
}
exports.deliverMessage = deliverMessage;

function removeMessage(name, id, handler) {
  dbClient.srem(playerMessagePrefix+name, id, handler);
  dbClient.del(messagePrefix+id);
}
exports.removeMessage = removeMessage;

exports.removeDungeon = function (name, handler) {
  dbClient.hdel(playerPrefix + name, 'dungeonData', handler);
}
/////////////////// Friends ///////////////////
exports.removeFriend = function (name, friendName, callback) {
  async.parallel([
      function (cb) { dbClient.srem(friendPrefix+name, friendName, cb); },
      function (cb) { dbClient.srem(friendPrefix+friendName, name, cb); },
      function (cb) { publishPlayerChannel(friendName, JSON.stringify({action: 'RemovedFromFriendList', name: name}), cb); }
    ],
    callback);
};

exports.extendFriendLimit = function (name, callback) {
  async.waterfall([
        function (cb) { dbClient.hget(sharedPrefix+name, 'contactLimit', cb); },
        function (limit, cb) { dbClient.hset(sharedPrefix+name, 'contactLimit', 5 + Number(limit), cb); }
      ],
      callback);
};

function getFriendList (name, callback) {
  async.parallel({
      book : function (cb) { dbClient.smembers(friendPrefix+name, cb); },
      limit : function (cb) { dbClient.hget(sharedPrefix+name, 'contactLimit', cb); }
    },
    callback);
};

exports.makeFriends = function (name, friendName, callback) {
  function helper(theName, theError) {
    return function (cb) {
      getFriendList(theName, function (err, i) {
        if (i.book.length >= i.limit) err = theError;
        cb(err, i);
      });
    };
  }
  async.series([
      helper(name, RET_FriendListFull), 
      helper(friendName, RET_OtherFriendListFull),
      function (cb) { dbClient.sadd(friendPrefix+name, friendName, cb); },
      function (cb) { dbClient.sadd(friendPrefix+friendName, name, cb); },
      //TODO:function (cb) { publishPlayerChannel(friendName, JSON.stringify({action: 'AddedToFriendList', name: name}), cb); }
      function (cb) { publishPlayerChannel(friendName, 'New Friend', cb); }
    ], callback);
};


exports.getFriendList = getFriendList;

var channelConfig = {};
publish = function (channel, message, cb) {
  if (publisher) publisher.publish(channel, JSON.stringify(message), cb);
};
exports.publish = publish;

publishPlayerChannel = function (name, message, cb) {
  channel = PlayerChannelPrefix+name;
  exports.publish(channel, message, cb);
};
exports.publishPlayerChannel = publishPlayerChannel;

exports.unsubscribe = function (channel) {
  subscriber.unsubscribe(channel);
  channelConfig[channel] = null;
}
exports.subscribe = function (channel, callback) {
  if (subscriber) subscriber.subscribe(channel);
  if (channelConfig[channel] == null) channelConfig[channel] = [];
  channelConfig[channel].push(callback);
};

exports.queryLeaderboardLength = function (board, handler) {
  var dbKey = 'Leaderboard.'+board;
  console.log(dbKey);
  dbClient.zcard(dbKey, handler);
};

dbSeparator = '.';
exports.initializeDB = function (cfg) {
  accountDBClient = redis.createClient(cfg.Account.PORT, cfg.Account.IP);
  dbClient = redis.createClient(cfg.Role.PORT, cfg.Role.IP);
  publisher = redis.createClient(cfg.Publisher.PORT, cfg.Publisher.IP);
  subscriber = redis.createClient(cfg.Subscriber.PORT, cfg.Subscriber.IP);
  subscriber.on("message", wrapCallback(function (channel, message) {
    var msg = JSON.parse(message);
    channelConfig[channel].forEach(function (c) { c(msg); });
  }), function (channel, message) {
    logError({info:'Parse Message Error', message:message});
  });

  dbClient.on('error', function (err) { logError({type: 'DB_Error', error: err}); });
  publisher.on('error', function (err) { logError({type: 'Publisher_Error', error: err}); });
  subscriber.on('error', function (err) { logError({type: 'Subscriber_Error', error: err}); });
  accountDBClient.on('error', function (err) { logError({type: 'AccountDB_Error', error: err}); });

  playerPrefix = dbPrefix + 'player' + dbSeparator;
  dungeonPrefix = dbPrefix + 'dungeon' + dbSeparator;
  messagePrefix = dbPrefix + 'message' + dbSeparator;
  playerMessagePrefix = dbPrefix + 'playerMessage' + dbSeparator;
  mercenaryPrefix = dbPrefix + 'mercenary' + dbSeparator;
  friendPrefix = dbPrefix + 'friend' + dbSeparator;
  sharedPrefix = dbPrefix + 'shared' + dbSeparator;
  limitsPrefix = dbPrefix + 'limits' + dbSeparator;

  LeaderboardPrefix = 'Leaderboard';

  sessionPrefix = dbPrefix + 'Session';

  PlayerNameSet = dbPrefix + 'UsedName';
  CurrentAccountID = 'CurrentUID';

  PlayerChannelPrefix = 'PlayerChannel_';

  passportPrefix = 'Passport';
  accPrefix = 'Account';
  ReceiptPrefix = 'Receipt';

  authPrefix = 'Auth';

  // Scripts
  accountDBClient.script('load', lua_createPassportWithAccount, function (err, sha) {
    createPassportWithAccount = function (type, id, handler) {
      accountDBClient.evalsha(sha, 0, type, id, (new Date()).valueOf(), handler);
    };
  });

  dbClient.script('load', lua_createSessionInfo, function (err, sha) {
    exports.newSessionInfo = function (handler) {
      dbClient.evalsha(sha, 0, dbPrefix, (new Date()).valueOf(),
        queryTable(TABLE_VERSION, 'bin_version'),
        queryTable(TABLE_VERSION, 'resource_version'),
        function (err, ret) {
          if (handler) { handler(err, ret); }
        });
    };
  });
  dbClient.script('load', lua_createNewPlayer, function (err, sha) {
    doCreateNewPlayer = function (account, prefix, name, handler) {
      dbClient.evalsha(sha, 0, prefix, name, account, function (err, ret) {
        if (ret === 'NameTaken') {
          err = new Error(RET_NameTaken);
        }
        if (handler) { handler(err, ret); }
      });
    };
  });
  dbClient.script('load', lua_queryLeaderboard, function (err, sha) {
    exports.queryLeaderboard = function (board, name, from, to, handler) {
      dbClient.evalsha(sha, 0, board, name, from, to, function (err, ret) {
        if (!err) {
          ret = {
            position: ret[0],
            board: ret[1]
          };
        }
        if (handler) { handler(err, ret); }
      });
    };
  });
  dbClient.script('load', lua_fetchMessage, function (err, sha) {
    exports.fetchMessage = function (name, handler) {
      dbClient.evalsha(sha, 0, dbPrefix, name, function (err, ret) {
        if (handler) { handler(err, JSON.parse(ret)); }
      });
    };
  });
  dbClient.script('load',lua_searchRival, function (err, sha) {
    exports.searchRival = function (name, handler) {
      dbClient.evalsha(sha, 0, 'Arena', name, Math.random(), Math.random(), Math.random(), function (err, ret) {
       if (handler) { handler(err, ret); }
      });
    };
  });
  dbClient.script('load',lua_exchangeScore, function (err, sha) {
    exports.saveSocre= function (champion, second, handler) {
      dbClient.evalsha(sha, 0, 'Arena', champion, second, function (err, ret) {
       if (handler) { handler(err, ret); }
      });
    };
  });
  dbClient.script('load',lua_getPvpInfo, function (err, sha) {
    exports.getPvpInfo= function (name, handler) {
      dbClient.evalsha(sha, 0, 'Arena', name, function (err, ret) {
       if (handler) { handler(err, ret); }
      });
    };
  });



//function fetchMessage(name, handler) {
//  dbClient.smembers(playerMessagePrefix+name, function (err, ids) {
//    async.map(
//      ids, 
//      function (id, cb) { dbClient.get(messagePrefix+id, cb); },
//      function (err, results) {
//        if (results) results = results.map(JSON.parse);
//        if (handler) handler(err, results);
//      });
//  });
//}
//exports.fetchMessage = fetchMessage;

};

exports.releaseDB = function () {
  if (dbClient) {
    accountDBClient.quit();
    dbClient.quit();
    publisher.quit();
    subscriber.quit();
    accountDBClient = null;
    dbClient = null;
    publisher = null;
    subscriber = null;
  }
};

exports.broadcast = function (message, handler) {publish('broadcast', message, handler);}; 
exports.broadcastEvent = function (type, arg, handler) {
  // TODO: internal cd
  arg.typ = type;
  exports.broadcast({
    NTF: Event_Broadcast,
    arg: arg
  });
}; 

exports.getGlobalPrize = function (handler) { dbClient.get("GlobalPrize", handler); };

exports.getServerConfig = function (key, handler) {
  dbClient.hget("ServerConfig", key, handler);
};
exports.setServerConfig = function (key, value, handler) {
  dbClient.hset("ServerConfig", key, value, handler);
};
