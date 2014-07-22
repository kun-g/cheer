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

function checkArgs(args, checkLst,output) {
  if (checkLst == null) {
    return;
  }

  for (var argName in checkLst) {
    var argType = checkLst[argName];
    var optional = false;
    if (typeof(argType) == 'object') {
      optional = argType.opt;
      argType = argType.type;
      if (typeof(optional) == 'undefined' || typeof(argType) == 'undefined' ){
        var errmsg = 'optional set must have key opt and type';
        if (typeof (output) == 'function') {
          output(errmsg);
        }else {
          throw Error(errmsg);
        }
      }
    }
    var realType = typeof(args[argName]);
    if (realType != argType) {
      if (!(realType == 'undefined' && optional)) {
        if (typeof (output) == 'function') {
          output({argName : argName, expectType : argType, actualType : typeof(args[argName])});
        }else{
          throw Error("arg type invalid: arg:"+argName+" expected:" 
              +argType +" actual:" +typeof(args[argName]));
        }
      }
    }
  }
  return;
}

exports.checkArgs = checkArgs;

function dispatchCommand (routeTable, req, socket, retValHandler) {
  function argErrorHandler(errorArg) {
    console.log({
      type : 'Handler Failed',
      cmd : req.CMD,
      error_message : "arg type invalid: arg:"+errorArg.argName+" expected:" 
              +errorArg.expectType+" actual:" +errorArg.actualType});
  }

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

      checkArgs(req.arg, handler.args,argErrorHandler)
   
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
