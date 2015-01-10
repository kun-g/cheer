//require('strong-agent').profile();
//require('nodetime').profile({
//  accountKey: 'c82d52d81e9ed18e8550b58bf36f49d47e50a792',
//  appName: 'DR'
//});
//var agent = require('webkit-devtools-agent');
require('./define');
require('./shop');
dbLib = require('./db');
dbWrapper = require('./dbWrapper');
http = require('http');
async = require('async');
var helperLib = require('./helper');
var event_cfg = require('./event_cfg');
var domain = require('domain').create();
domain.on('error', function (err) {
  console.log("UnhandledError", err, err.message, err.stack);
});


//playerCounter = 0;
//memwatch = require('memwatch');
//var tmp = new memwatch.HeapDiff();
//memwatch.on('leak', function (info) {
//  logWarn(info);
//  var diff = tmp.end();
//  diff.change.details = diff.change.details.sort( function (a, b) {
//    return b.size_bytes - a.size_bytes;
//  });
//  logWarn(diff);
//  console.log( playerCounter );
//  tmp = new memwatch.HeapDiff();
//});

var libServer = require("./server");
gServer = new libServer.Server();
exports.server = gServer;

function initiateLogger() {
  logger = {};
  initiateFluentLogger();
  initiateTrinLogger();
  logger.emit = function (type, log, time) {
    if (logger.tr_agent) {
      logger.tr_agent.write(JSON.stringify({type: type, log: log, time: time.valueOf()}));
    }
    if (logger.td_agent) {
      logger.td_agent.emit(type, log, time);
    }
  };
}
function initiateTrinLogger() {
  var dgram = require('dgram');
  var socket = dgram.createSocket('udp4');
  logger.tr_agent = {
    write: function (msg) {
      var buf = new Buffer(msg);
      socket.send(buf, 0, buf.length, 9528, '10.4.3.41');
    }
  };
  function trinLoggerErrorHandler () {
    logger.tr_agent = null;
    setTimeout(function (err) { initiateTrinLogger(); }, 10000);
  }
  socket.on('close', trinLoggerErrorHandler);
  socket.on('error', trinLoggerErrorHandler);
}
function initiateFluentLogger() {
  logger.td_agent = require('fluent-logger');
  logger.td_agent.configure('td.game', {host: 'localhost', port: 9527});
  logger.td_agent.on('error', function (err) {
    logger.td_agent = null;
    setTimeout(function () { initiateFluentLogger(); }, 10000);
  });
}


function isRMBMatch(amount, receipt) {
  productList = queryTable(TABLE_IAP, 'list');
  rec = unwrapReceipt(receipt);
  cfg = productList[rec.productID];
  return cfg && cfg.price == amount;
}

function paymentHandler (request, response) {
  if (request.url.substr(0, 5) === '/pay?') {
    var ppKey = '-----BEGIN PUBLIC KEY-----\n' +
        'MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEArjB/MQESS9k2Xejv0yN8\n'+
        't3qQ+IO8UqRTNeqgE4GoPBzmyPY4XJVcijAm7eHkUaF6yxGDh8D03R/yhrQBSdJ1\n'+
        'GHLEew3KH3VgKNigdN9LGfJuH+k6JgCHwVK+diEQCzkhF6D7qrDvLNkF5iNQr2D+\n'+
        '3lDAoAhE/PbYvJTH6KGIwx+TJtnNjJMhdE8WmWY5/3OAgyFU6DwVJs4phYWwZsYY\n'+
        '+Z8s6sq7xKjYeCS0vVonNZ6m9VnYhv1NknxbHDovOMY3Ix/hsu+g2YiJFuUlyyaR\n'+
        'bM4NUbZfu9OcfAGMo0L2vl6x/x7WzWBRKIGO7ONELfeit3PEPxE0kBvunAMPkQb5\n'+
        'cwIDAQAB\n'+
        '-----END PUBLIC KEY-----';
    var data = new Buffer(0);
    request.on('data', function (chunk) { data = Buffer.concat([data, chunk]); });
    request.on('end', function (chunk) {
      data = 'pay?'+data.toString();
      var out = urlLib.parse(data, true).query;
      if (out.sign) {
        var cipher = rsaLib.createPublicKey(ppKey);
        var info = cipher.publicDecrypt(new Buffer(out.sign, 'base64'), null, 'utf8');
        info = JSON.parse(info);
        var receipt = info.billno;
        if (out.order_id === info.order_id && out.amount === info.amount && isRMBMatch(info.amount, info.billno)) {
          deliverReceipt(receipt, 'PP25', function (err) {
            if (err === null) {
              logInfo({action: 'AcceptPayment', receipt: receipt, info: info});
              return response.end('success');
            } else {
              logError({action: 'AcceptPayment', error:err, data: data});
              response.end('fail');
            }
          });
        }
      }
      data = null;
    });
    request.on('error', function (err) {
      logError({action: 'AcceptPayment', error:err, data: data});
      response.end('fail');
    });
  } else if (request.url.substr(0, 5) === '/911?') {
    out = urlLib.parse(request.url, true).query;
    var appKey = '';
    if (out.AppId == '115411') {
      appKey = '77bcc1c2b9cf260b12f124d1c280ae1de639b89e127842b1';
    } else if (out.AppId == '112988') {
      appKey = 'd30d9f0f53e2654274505e25c27913fe709eb1ad6265e5c5';
    }
    var sign = out.AppId+out.Act+out.ProductName+out.ConsumeStreamId+out.CooOrderSerial+
        out.Uin+out.GoodsId+out.GoodsInfo+out.GoodsCount+out.OriginalMoney+out.OrderMoney+
        out.Note+out.PayStatus+out.CreateTime+appKey;
    var b = new Buffer(1024);
    var len = b.write(sign);
    sign = md5Hash(b.toString('binary', 0, len));
    var receipt = out.CooOrderSerial;
    if (sign === out.Sign && isRMBMatch(out.OrderMoney, receipt)) {
      deliverReceipt(receipt, 'ND91', function (err) {
        if (err === null) {
          logInfo({action: 'AcceptPayment', receipt: receipt, info: out});
          return response.end('{"ErrorCode": "1", "ErrorDesc": "OK"}');
        } else {
          logError({action: 'AcceptPayment', error:err, info: out, receiptInfo: receiptInfo});
          return response.end('{"ErrorCode": "0", "ErrorDesc": "Fail"}');
        }
      });
    } else {
      logError({action: 'AcceptPayment', error: 'SignMissmatch', info: out, sign: sign});
      response.end('{"ErrorCode": "5", "ErrorDesc": "Fail"}');
    }
    b = null;
  } else if (request.url.substr(0, 4) === '/kyp') {
    var kyKey = '-----BEGIN PUBLIC KEY-----\n' +
        'MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDhELQrtgj6aE81F8o74lOFg7l6\n'+
        'bUZqe4VQe0MURr0G0zh/hY/KIIxoYfYWBQMwONy0vV23O5XKJDpAJUBHs92mJdB3\n'+
        'lk95/RsqP0TCpKikrEySLOz9Kfzbf5VWQLRtP4ANfQZbc5K5yrN9Y5D7Ocl2m7pw\n'+
        '7g9TLkJT1Ue+Mg+kYwIDAQAB\n'+
        '-----END PUBLIC KEY-----';
    var data = new Buffer(0);
    request.on('data', function (chunk) { data = Buffer.concat([data, chunk]); });
    request.on('end', function (chunk) {
      data = 'pay?'+data.toString();
      var out = urlLib.parse(data, true).query;
      if (out.notify_data) {
        var cipher = rsaLib.createPublicKey(kyKey);
        var info = cipher.publicDecrypt(new Buffer(out.notify_data, 'base64'), null, 'utf8');
        info = urlLib.parse('pay?'+info, true).query;
        var receipt = info.dealseq;
        if (info.payresult == 0 && isRMBMatch(info.fee, receipt)) {
          deliverReceipt(receipt, 'KY', function (err) {
            if (err) {
              logError({action: 'AcceptPayment', error: err, receipt: receipt});
              response.end('failed');
            } else {
              logInfo({action: 'AcceptPayment', receipt: receipt, info: info});
              response.end('success');
            }
          });
        } else {
          response.end('failed');
        }
      } else {
        response.end('failed');
      }
      data = null;
    });
    request.on('error', function (err) {
      logError({action: 'AcceptPayment', error:err, data: data});
      data = null;
      response.end('failed');
    });
  } else if (request.url.substr(0, 5) === '/DKP?') {
    out = urlLib.parse(request.url, true).query;
    appSecret = 'KvCbUBBpAUvkKkC9844QEb8CB7pHnl5v'
    var sign = out.amount+out.cardtype+out.orderid+out.result+out.timetamp+appSecret+out.aid;
    var b = new Buffer(1024);
    var len = b.write(sign);
    sign = md5Hash(b.toString('binary', 0, len));
    var receipt = out.orderid;
    if (sign === out.client_secret ){ //&& isRMBMatch(out.OrderMoney, receipt)) {
      if (out.result === '1'){
        deliverReceipt(receipt, 'DK', function (err) {
          if (err === null) {
            logInfo({action: 'AcceptPayment', receipt: receipt, info: out});
          } else {
            logError({action: 'AcceptPayment', error:err, info: out, receiptInfo: receiptInfo});
          }
        });
      }
      return response.end('SUCCESS');
    } else {
      logError({action: 'AcceptPayment', error: 'SignMissmatch', info: out, sign: sign});
      response.end('ERROR_SIGN');
    }
    b = null;
  } else if (request.url.substr(0, 5) === '/TBK?') {
    var query = urlLib.parse(request.url, true).query;
    var receipt = query.receipt;
    var data = new Buffer(0);
    request.on('data', function (chunk) { data = Buffer.concat([data, chunk]); });
    request.on('end', function (chunk) {
      data = 'pay?'+data.toString();
      var out = urlLib.parse(data, true).query;
      var token = '';
      //if (out.app_id == 'org.kddxc.koudaidixiachengapk1' || out.app_id == 'org.kddxc.koudaidixiachengapk') {
      //  token = "bf0d10d4f9979d3c6aae26011b6ec34b";
      //} else {
      //  token = "c2a8c153eec815118179f46e0dbfd99e";
      //}
      token = "bf0d10d4f9979d3c6aae26011b6ec34b";
      if (out.type) {
        var sign = out.order_id+'|'+out.app_id+'|'+out.product_id+'|'+out.uid
            +'|'+out.goods_count+'|'+out.original_money+'|'+out.order_money
            +'|'+out.pay_status+'|'+out.create_time +'|'+out.type+'|'+out.value+'|'+token;
      } else {
        var sign = out.order_id+'|'+out.app_id+'|'+out.product_id+'|'+out.uid
            +'|'+out.goods_count+'|'+out.original_money+'|'+out.order_money
            +'|'+out.pay_status+'|'+out.create_time +'|'+token;
      }

      var b = new Buffer(1024);
      var len = b.write(sign);
      sign = md5Hash(b.toString('binary', 0, len));

      if ((sign === out.md5) && isRMBMatch(out.order_money, receipt)) {
        deliverReceipt(receipt, 'Teebik', function (err) {
          if (err === null) {
            logInfo({action: 'AcceptPayment', receipt: receipt, info: out});
            return response.end(JSON.stringify({success:1, msg: "OK"}));
          } else {
            logError({action: 'AcceptPayment', error:err, data: data});
            return response.end('fail');
          }
        });
      } else {
        logError({action: 'AcceptPayment', error: 'Fail', data: data});
        response.end(JSON.stringify({success:0, msg: "Arguments miss match."}));
      }
      data = null;
    });
  } else if (request.url.substr(0, 5) === '/jdp?') {
  }
}

function deliverReceipt (receipt, tunnel, cb) {
  var receiptInfo = unwrapReceipt(receipt);
  var serverName = ServerNames[receiptInfo.serverID];
  if (serverName) {
    return cb(Error( 'InvalidServerID' ));
  }
  var message = {
    type: MESSAGE_TYPE_ChargeDiamond,
    paymentType: tunnel,
    receipt: receipt
  };

  async.waterfall([
    function (cb) {
      dbLib.updateReceipt(
          receipt,
          RECEIPT_STATE_AUTHORIZED,
          receiptInfo.id,
          receiptInfo.productID,
          receiptInfo.serverID,
          receiptInfo.tunnel,
          cb);
    },
    function (_, cb) { dbLib.getPlayerNameByID(receiptInfo.id, serverName, cb); },
    function (name, cb) { dbLib.deliverMessage(name, message, cb, serverName); },
    function (_, cb) {
      dbLib.updateReceipt(
          receipt,
          RECEIPT_STATE_DELIVERED,
          receiptInfo.id,
          receiptInfo.productID,
          receiptInfo.serverID,
          receiptInfo.tunnel,
          cb);
    }
  ], cb);
}


gServerObject = {
    getType: function () { return 'server'; },
    type: 'server'
};

gNewCampainTable = {
    startupPlayer: {
        storeType: "player",
        counter: {
            key: 'startupReward',
            initial_value: 0,
            count_down: { time: 'time@ThisCounter', units: 'day' }
        },
        available_condition: [
            { type: 'counter', func: "notCounted" },
            {
                type: 'function',
                func: function (theData, utils) {
                    return startup_campaign_server.isActive(theData.object.getServer(), theData.time);
                }
            }
        ],
        activate: function (theData, util) {
            var obj = theData.object;
            var server = obj.getServer();
            var prize = server.startup_reward;
            dbLib.deliverMessage(obj.name, {
                type: MESSAGE_TYPE_SystemReward,
                src: MESSAGE_REWARD_TYPE_SYSTEM,
                prize: prize,
                tit: "测试服小福利",
                txt: "祝各位2015万事如意"
            });
        }
    },
    startupServer: {
        storeType: "server",
        counter: {
            key: 'startupReward',
            initial_value: -1,
            uplimit: 7,
            count_down: { time: 'time@ThisCounter', units: 'day' }
        },
        available_condition: [ { type: 'counter', func: "notFulfiled" } ],
        prize: [
            [ {"type":1,"count":10000}, {"type":2,"count":2015} ],
            [ {"type":1,"count":10000}, {"type":2,"count":2015} ],
            [ {"type":1,"count":10000}, {"type":2,"count":2015} ],
            [ {"type":1,"count":10000}, {"type":2,"count":2015} ],
            [ {"type":1,"count":10000}, {"type":2,"count":2015} ],
            [ {"type":1,"count":10000}, {"type":2,"count":2015} ],
            [ {"type":1,"count":10000}, {"type":2,"count":2015} ]
        ],
        update: function (theData, util) {
            var obj = theData.object;
            var counter = obj.counters.startupReward.counter;
            obj.startup_reward = this.prize[counter];
            var key = this.counter.key;
            dbLib.setServerProperty("counters", key, JSON.stringify(obj.counters[key]));
        }
    }
};
libCampaign = require("./campaign")
var startup_campaign_server = new libCampaign.Campaign(gNewCampainTable.startupServer);
function updateServerConfig (appNet) {
  appNet.aliveConnections = appNet.aliveConnections
      .filter(function (c) {return c!==null;})
      .map(function (c, i) { c.connectionIndex = i; return c;});
  dbLib.getGlobalPrize(function (err, prize) { gGlobalPrize = JSON.parse(prize); });
}

function init() {
    var appNet = gServer.startTcpServer(gServerConfig);

    updateServerConfig(appNet);
    var tcpInterval = setInterval(function () { updateServerConfig(appNet); }, 100000);
    gServer.serverInfo.type = gServerConfig.type;
    serverType = gServerConfig.type;
    dbLib.subscribe('login', function (message) {
      try {
        var info = JSON.parse(message);
        if (gPlayerDB[info.player] && gPlayerDB[info.player].runtimeID !== info.session) {
          gPlayerDB[info.player].logout(RET_LoginByAnotherDevice);
          delete gPlayerDB[info.player];
        }
      } catch (err) {
        logError({type: 'loginSubscribe', error:err});
      }
    });
    dbLib.subscribe('broadcast', function (message) {
      gServer.tcpServer.net.aliveConnections.forEach(function (c) {
        if (c.playerName) c.encoder.writeObject(message);
      });
    });
    dbLib.subscribe('ServerInfo', function (info) {
    });
}

initiateLogger();
initServer();
initGlobalConfig(null, function () {

var dbConfig = queryTable(TABLE_CONFIG, "DB_Config");
var svConfig = queryTable(TABLE_CONFIG, "Server_Config");
var ipConfig = queryTable(TABLE_CONFIG, "IP_Config");

ServerNames = [];
for (var k in svConfig) {
    if (svConfig[k].ID != -1) {
        ServerNames[svConfig[k].ID] = svConfig[k].Name;
    }
}

var ips = [];
var networkInterfaces = require("os").networkInterfaces();
for (var key in networkInterfaces) {
    ips = ips.concat(networkInterfaces[key].map(function (e) { return e.address; }));
}
var ip = ips.filter(function (e) { return ipConfig[e]; })[0];

var index = 0;
if (process.argv[2]) {
    index = Number(process.argv[2]);
}

g_ipConfig = ipConfig[ip][index];
g_svConfig = svConfig[g_ipConfig.Server];
g_dbConfig = dbConfig[g_svConfig.DB];
g_DEBUG_FLAG = g_svConfig.Debug;
gServerConfig = {
  type: "Worker",
  port: g_ipConfig.Port,
  handler: require("./commandHandlers").route
};
gServerID = g_ipConfig.Server;
gServerName = g_svConfig.Name;
dbPrefix = g_svConfig.DB_Prefix+dbSeparator;
dbLib.initializeDB(g_dbConfig);
dbLib.getGlobalPrize(function (err, prize) { gGlobalPrize = JSON.parse(prize); });
require('./helper').initLeaderboard(queryTable(TABLE_LEADBOARD));
domain.run(init);

// Pay
urlLib = require('url');
cryptoLib = require('crypto');
rsaLib = require('ursa');

paymentServer = require('http').createServer(wrapCallback(paymentHandler));
paymentServer.on('error', function (error) {
    if (error.code == 'EADDRINUSE') {
        paymentServer = null;
    } else {
        logError({action: 'Startup', error:error });
    }
});
paymentServer.listen(6499);

var intervalCfg = {};
config = event_cfg.intervalEvent;
async.series([
      function (cb) {
        dbLib.getServerProperty('counters', function (err, arg) {
          gServerObject.counters = {};
          if (arg) {
              for (var k in arg) {
                gServerObject.counters[k] = JSON.parse(arg[k]);
              }
          }
          cb();
        });
      }],
    function (err, ret) {
      var helperLib = require('./helper');
      helperLib.initCampaign(gServerObject, event_cfg.events);
      helperLib.initObserveration(gServerObject);

      var now = helperLib.currentTime();
      if (startup_campaign_server.isActive(gServerObject, now)) {
          startup_campaign_server.activate(gServerObject, 1, now);
          startup_campaign_server.update(gServerObject, now);
      }

      gServerObject.installObserver('countersChanged');
    });
dbLib.getServerConfig('Interval', function (err, arg) {
  if (arg) { intervalCfg = JSON.parse(arg); }

  // TODO: 多个服务器的情况
  dbLib.setServerConfig('Interval', JSON.stringify(intervalCfg));
  setInterval(function () {
    var flag = false;
    for (var key in config) {
      var cfg = config[key];
      var now = helperLib.currentTime();
      var moment = require('moment');
      if (helperLib.matchDate(now, now, cfg.time) &&
          (!intervalCfg[key] || !moment().isSame(intervalCfg[key], 'day'))
      ) {
        cfg.func({helper: helperLib, db: require('./db'), sObj: gServerObject});
        intervalCfg[key] = helperLib.currentTime();
        flag = true;
      }
    }
    if (flag) {
      dbLib.setServerConfig('Interval', JSON.stringify(intervalCfg));
    }
  }, 6000);

  gHuntingInfo = {};
  dbLib.getServerConfig('huntingInfo', function (err, arg) {
    if (arg) { gHuntingInfo = JSON.parse(arg); }
  });
  gReward_modifier = {}
  dbLib.getServerConfig('reward_modifier', function (err, arg) {
    if (arg) { gReward_modifier = JSON.parse(arg); }
  });
});
});
/*
 process.on('SIGINT', function () {
 logInfo('Got SIGINT');
 gServer.shutDown();
 });
 */

