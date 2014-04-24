//require('strong-agent').profile();
require('nodetime').profile({
  accountKey: 'c82d52d81e9ed18e8550b58bf36f49d47e50a792', 
  appName: 'DR'
});
var agent = require('webkit-devtools-agent');
require('./define');
dbLib = require('./db');
dbWrapper = require('./dbWrapper');
http = require('http');
var domain = require('domain').create();
domain.on('error', function (err) {
  console.log("UnhandledError", err.message, err.stack);
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

var srvLib = require("./server");
gServer = new srvLib.Server();
exports.server = gServer;

function initiateFluentLogger() {
  logger = require('fluent-logger');
  logger.configure('td.game', {host: 'localhost', port: 9527});
  logger.on('error', function (err) {
    logger = null;
    setTimeout(function () {
      logError({msg:"Try to reconnect to fluent.", error: err});
      initiateFluentLogger();
    }, 10000);
  });
}

var config = {
  port: 7756, 
  type : 'Worker',
  handler: require("./commandHandlers").route,
  init : function () {
    gServer.startTcpServer(config);
    gServer.serverInfo.type = config.type;
    serverType = config.type;
    dbLib.subscribe('login', function (message) {
      try {
        var info = JSON.parse(message);
        if (gPlayerDB[info.player] && gPlayerDB[info.player].runtimeID !== info.session) {
          gPlayerDB[info.player].logout(RET_LoginByAnotherDevice);
          delete gPlayerDB[info.player]
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
};

//process.argv.forEach(function (val, index, array) {
//  if (handlerConfig[val]) {
//    config = handlerConfig[val];
//  }
//});

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
        if (out.order_id === info.order_id && out.amount === info.amount) {
          var receipt = info.billno;
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
    var appKey = 'd30d9f0f53e2654274505e25c27913fe709eb1ad6265e5c5';
    var sign = out.AppId+out.Act+out.ProductName+out.ConsumeStreamId+out.CooOrderSerial+
      out.Uin+out.GoodsId+out.GoodsInfo+out.GoodsCount+out.OriginalMoney+out.OrderMoney+
      out.Note+out.PayStatus+out.CreateTime+appKey;
    var b = new Buffer(1024);
    var len = b.write(sign);
    sign = md5Hash(b.toString('binary', 0, len));
    if (sign === out.Sign) {
      var receipt = out.CooOrderSerial;
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
        if (info.payresult == 0) {
          var receipt = info.dealseq;
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
  }
}

function deliverReceipt (receipt, tunnel, cb) {
  var receiptInfo = unwrapReceipt(receipt);
  var cfg = queryTable(TABLE_CONFIG, 'ServerConfig');
  if (!cfg[receiptInfo.serverID]) {
    return cb(Error( 'InvalidServerID' ));
  }
  var serverName = cfg[receiptInfo.serverID].Name;
  var message = {
          type: MESSAGE_TYPE_ChargeDiamond,
          paymentType: tunnel,
          receipt: receipt
        };
  async.waterfall([
    function (cb) { dbWrapper.updateReceipt(receipt, RECEIPT_STATE_AUTHORIZED, cb); },
    function (_, cb) { dbLib.getPlayerNameByID(receiptInfo.id, serverName, cb); },
    function (name, cb) { dbLib.deliverMessage(name, message, cb, serverName); },
    function (_, cb) { dbWrapper.updateReceipt(receipt, RECEIPT_STATE_DELIVERED, cb); }
  ], cb);
}

if (config) {
  initiateFluentLogger();
  initServer();
  initGlobalConfig(null, function () {
    gServerID = queryTable(TABLE_CONFIG, 'ServerID');
    gServerConfig = queryTable(TABLE_CONFIG, 'ServerConfig')[gServerID];
    gServerName = gServerConfig.Name;
    dbPrefix = gServerName+dbSeparator;
    dbLib.initializeDB(gServerConfig.DB);
    require('./helper').initLeaderboard(queryTable(TABLE_LEADBOARD));
    domain.run(config.init);

    // Pay
    urlLib = require('url');
    cryptoLib = require('crypto');
    rsaLib = require('ursa');

    paymentServer = require('http').createServer(wrapCallback(paymentHandler));
    paymentServer.listen(6499);
  });
} else {
  throw 'No config';
}
/*
process.on('SIGINT', function () {
  logInfo('Got SIGINT');
  gServer.shutDown();
});
*/

