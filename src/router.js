var dbLib = require('./db');
var define = require("./define");
var async = require('async');

function route(handler, request, socket, callBack) {
  var startTime = process.hrtime();

  function handleReturnVal (retObj) {
    var profileLog = {
      endTime: process.hrtime(startTime),
      request: request,
      response: retObj
    };
    logInfo(profileLog);
    callBack(retObj);	
  }

  if (request != null) dispatchCommand(handler, request, socket, handleReturnVal);
}

backupTable = require('./requestHandlers.js').route;
reverseTable = { };
for (var k in backupTable) {
  reverseTable[backupTable[k].id] = k;
}

function v_dispatchCommand (routeTable, req, socket, retValHandler) {
  if (req == null) {
    return logError({type : 'Req Missing'});
  }

  if (req.CMD == null) req.CMD = req.CNF;
  var handler = routeTable[req.CMD];
  if (handler == null) handler = backupTable[reverseTable[req.CMD]];

  if (handler == null || typeof handler['func'] !== 'function') {
    return logError({type : 'Handler Missing', cmd : req.CMD});
  } 

  var player = socket.player;
  async.waterfall([
    function (cbb) { if (!handler.needPid) { cbb(Error(RET_OK)); } else { cbb(null); } },
    function (cbb) {
      if (player != null) {
        if (player.runtimeID !== req.PID) {
          cbb(RET_SessionOutOfDate);
        } else {
          cbb(Error(RET_OK));
        }
      } else {
        cbb(null);
      }
    },
    function (cbb) { dbLib.loadSessionInfo(req.PID, cbb); },
    function (sessionInfo, cbb) { if (!sessionInfo) cbb(RET_SessionOutOfDate); else cbb(null, sessionInfo); },
    function (info, cbb) {
      if ( info.bin_version != queryTable(TABLE_VERSION, 'bin_version') ||
           info.resource_version != queryTable(TABLE_VERSION, 'resource_version') ) {
             cbb( RET_NewVersionArrived );
           } else {
             cbb( null, info.player );
           }
    },
    function (playerName, cbb) { dbLib.loadPlayer(playerName, cbb); },
    function (p, cbb) { if (!p || p.runtimeID !== req.PID) cbb(RET_SessionOutOfDate); else cbb(null, p); },
    function (p, cbb) {
      p.onReconnect(socket);
      p.socket = socket;
      socket.player = p;
      socket.playerName = p.name;
      gPlayerDB[p.player] = p;
      p.updateFriendInfo(cbb);
      player = p;
    }], function (err, result) {
      if (err && err.message != RET_OK) {
        retValHandler([{NTF: Event_ExpiredPID, err: err}]);
      } else {
        try {
          handler.func(req.arg, player, retValHandler, req.REQ, socket, false, req);
        } catch (err) {
          logError({
            type : 'Handler Failed',
            error_message : err.message,
            stack : err.stack,
            req : req
          });
        }
      }
    });
}

function dispatchCommand (routeTable, req, socket, retValHandler) {
  if (req == null) {
    return logError({type : 'Req Missing'});
  }

  if (req.CMD == null) req.CMD = req.CNF;
  var handler = routeTable[req.CMD];
  if (handler == null) handler = backupTable[reverseTable[req.CMD]];

  if (handler == null || typeof handler['func'] !== 'function') {
    return logError({type : 'Handler Missing', cmd : req.CMD});
  } 

  var player = socket.player;
  if (player != null || !handler.needPid) {
    try {
      handler.func(req.arg, player, retValHandler, req.REQ, socket, false, req);
    } catch (err) {
      logError({
        type : 'Handler Failed',
        error_message : err.message,
        stack : err.stack,
        req : req
      });
    }
  } else {
    retValHandler([{NTF: Event_ExpiredPID, err: err}]);
  }
}

exports.route = route;
exports.peerOffline = function (socket) {
  //if (socket.playerName) gPlayerManager.delPlayer(socket.playerName);
};
