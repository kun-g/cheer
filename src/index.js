//require('strong-agent').profile();
require('./define');
dbLib = require('./db');
dbWrapper = require('./dbWrapper');
http = require('http');
var domain = require('domain').create();

domain.on('error', function (err) {
  console.log(err.message, err.stack);
});

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
  //timeout: 10000,
  type : 'Worker',
  handler: require("./commandHandlers").route,
  init : function () {
    gServerName = queryTable(TABLE_CONFIG, 'ServerName');
    dbPrefix = gServerName+dbSeparator;
    gServerID = queryTable(TABLE_CONFIG, 'ServerID');
    dbLib.initializeDB(queryTable(TABLE_CONFIG, 'DB_Config_'+gServerName));
    gServer.startTcpServer(config);
    gServer.serverInfo.type = config.type;
    serverType = config.type;
    dbLib.subscribe('login', function (message) {
      try {
        var info = JSON.parse(message);
        if (gPlayerDB[info.player] && gPlayerDB[info.player].runtimeID !== info.session) {
          gPlayerDB[info.player].logout(RET_LoginByAnotherDevice);
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

if (config) {
  initiateFluentLogger();
  initServer();
  initGlobalConfig(null, function () {
    domain.run(config.init);
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

// Pay
urlLib = require('url');
cryptoLib = require('crypto');
rsaLib = require('ursa');
key = '-----BEGIN PUBLIC KEY-----\n' +
'MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEArjB/MQESS9k2Xejv0yN8\n'+
't3qQ+IO8UqRTNeqgE4GoPBzmyPY4XJVcijAm7eHkUaF6yxGDh8D03R/yhrQBSdJ1\n'+
'GHLEew3KH3VgKNigdN9LGfJuH+k6JgCHwVK+diEQCzkhF6D7qrDvLNkF5iNQr2D+\n'+
'3lDAoAhE/PbYvJTH6KGIwx+TJtnNjJMhdE8WmWY5/3OAgyFU6DwVJs4phYWwZsYY\n'+
'+Z8s6sq7xKjYeCS0vVonNZ6m9VnYhv1NknxbHDovOMY3Ix/hsu+g2YiJFuUlyyaR\n'+
'bM4NUbZfu9OcfAGMo0L2vl6x/x7WzWBRKIGO7ONELfeit3PEPxE0kBvunAMPkQb5\n'+
'cwIDAQAB\n'+
'-----END PUBLIC KEY-----';

paymentServer = require('http').createServer(wrapCallback(function (request, response) {
  if (request.url.substr(0, 5) === '/pay?') {
    var data = new Buffer(0);
    request.on('data', function (chunk) { data = Buffer.concat([data, chunk]); });
    request.on('end', function (chunk) {
      data = 'pay?'+data.toString();
      var out = urlLib.parse(data, true).query;
      if (out.sign) {
        var cipher = rsaLib.createPublicKey(key);
        var info = cipher.publicDecrypt(new Buffer(out.sign, 'base64'), null, 'utf8');
        info = JSON.parse(info);
        if (out.order_id === info.order_id && out.amount === info.amount) {
          var receipt = info.billno;
          var receiptInfo = unwrapReceipt(receipt);
          var serverName = 'Master'; //TODO:多服的情况?
          dbWrapper.updateReceipt(receipt, RECEIPT_STATE_AUTHORIZED, function (err) {
            dbLib.deliverMessage(receiptInfo.name, {
              type: MESSAGE_TYPE_ChargeDiamond,
              paymentType: 'PP25',
              receipt: receipt
            }, function (err, messageID) {
              dbWrapper.updateReceipt(receipt, RECEIPT_STATE_DELIVERED, function () {});
            }, serverName);

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
      data = new Buffer(0);
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
      var receiptInfo = unwrapReceipt91(receipt);
      var serverName = 'Master'; //TODO:多服的情况?
      dbWrapper.updateReceipt(receipt, RECEIPT_STATE_AUTHORIZED, function (err) {
        dbLib.getPlayerNameByID(receiptInfo.id, serverName, function (err, name) {
          dbLib.deliverMessage(name, {
            type: MESSAGE_TYPE_ChargeDiamond,
            paymentType: 'ND91',
            receipt: receipt
          }, function (err, messageID) {
            dbWrapper.updateReceipt(receipt, RECEIPT_STATE_DELIVERED, function () {});
          }, serverName);
          if (err === null) {
            logInfo({action: 'AcceptPayment', receipt: receipt, info: out, receiptInfo: receiptInfo});
            return response.end('{"ErrorCode": "1", "ErrorDesc": "OK"}');
          } else {
            logError({action: 'AcceptPayment', error:err, info: out, receiptInfo: receiptInfo});
            return response.end('{"ErrorCode": "0", "ErrorDesc": "Fail"}');
          }
        });
     });
    } else {
      logError({action: 'AcceptPayment', error: 'SignMissmatch', info: out, sign: sign});
      response.end('{"ErrorCode": "5", "ErrorDesc": "Fail"}');
    }
  }
}));
paymentServer.listen(6499);
