var defLib = require('./define');
var dbLib = require('./db');
var parseLib = require('./requestStream');
var net = require('net');

function Server () {
  this.serverInfo = {
    serverID : process.pid+'_'+ Math.floor(Math.random() * 100000),
    isNew : true
  };
  this.serverList = {};
  var me = this;
  me.serverInfo.isNew = false;
}
Server.prototype.shutDown = function () {
  clearInterval(this.publishInterval);
  if (this.tcpServer) {
    this.tcpServer.net.close();
    //clearInterval(this.tcpServer.tcpInterval);
    this.tcpServer.net.aliveConnections.forEach(function (c) {
      if (c.pendingRequest.length == 0) c.end();
    });
  }
};

function destroySocket (c) {
  if (c.player) {
    var name = c.playerName;
    c.player.socket = null;
    c.player.logout();

    logUser({
      action: 'ioSize',
      send: c.encoder.totalBytes,
      recv: c.decoder.totalBytes,
      maxSend: c.encoder.maxBytes,
      maxRecv: c.decoder.maxBytes,
      name: name
    });
  } else {
    c.player = null;
    c.encoder = null;
    c.decoder = null;
    c.pendingRequest = null;
    c.destroy();
  }
}

Server.prototype.startTcpServer = function (config) {
  if (config == null || config.handler == null || config.port == null) {
    throw 'No handler';
  }

  var handler = config.handler;
  var appNet = net.createServer(function (c) {
    //console.log('New Connection', c.remoteAddress)
    appNet.aliveConnections.push(c);
    c.connectionIndex = appNet.aliveConnections.length - 1;
    c.pendingRequest = new Buffer(0);
    if (config.timeout) c.setTimeout(config.timeout);
    c.on('end', function () {
      destroySocket(c);
      delete appNet.aliveConnections[c.connectionIndex];
      c = null;
    });
    c.on('error', function () {
      destroySocket(c);
      delete appNet.aliveConnections[c.connectionIndex];
      c = null;
    });
    c.decoder = new parseLib.SimpleProtocolDecoder();
    c.encoder = new parseLib.SimpleProtocolEncoder();
    c.encoder.pipe(c);
    c.encoder.setFlag('size');
    //encoder.setFlag('messagePack');
    c.pipe(c.decoder);
    c.decoder.on('request', function (request) {
      if (!request) c.destroy();
      require("./router").route(handler, request, c, function (ret) { 
        if (ret && c) {
          c.encoder.writeObject(ret);
        }
      });
    });

  });
  appNet.aliveConnections = [];
  appNet.listen(config.port, function () {
    logInfo({
      action: 'startServer', 
      port: config.port, 
      ip: require('os').networkInterfaces(),
      bin_version: queryTable(TABLE_VERSION, 'bin_version'),
      resource_version: queryTable(TABLE_VERSION, 'resource_version')
    });
  });
  appNet.on('close', function () { onNetworkShutDown(); });
  appNet.on('error', function (e) {
    logError({
      type : 'Server Error',
      error : e
    });
  });
  this.tcpServer = {
    net : appNet,
    //tcpInterval : tcpInterval
  };
  this.serverInfo.port = config.port;

  me = this;
  dbLib.subscribe('ServerInfo', function (info) {
    info.time = new Date();
    me.serverList[info.serverID] = info;
    if (info.isNew && info.serverID != me.serverInfo.serverID) {
      dbLib.publish('ServerInfo', me.serverInfo); 
    }
  });
  dbLib.publish('ServerInfo', me.serverInfo);
  this.publishInterval = setInterval(function () {
    if (me.tcpServer) me.serverInfo.connections = me.tcpServer.net.aliveConnections.length;
    dbLib.publish('ServerInfo', me.serverInfo);
  }, 3000);
  return appNet;
};

exports.Server = Server;
