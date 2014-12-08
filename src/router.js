"use strict";
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

var backupTable = require('./requestHandlers.js').route;
var reverseTable = { };
for (var k in backupTable) {
  reverseTable[backupTable[k].id] = k;
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
      logInfo({ type : 'pendingRequest', req : req });

      handler.func(req.arg, player, retValHandler, req.REQ, socket, false, req);
    } catch (err) {
      logError({
        type : 'Handler Failed',
        error_message : err.message,
        stack : err.stack,
        err: err,
        req : req
      });
    }
  } else {
    retValHandler([{NTF: Event_ExpiredPID, err: RET_SessionOutOfDate}]);
  }
}

exports.route = route;
