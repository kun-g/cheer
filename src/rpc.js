var uuid = require("node-uuid");
var amqp = require('amqplib');
var when = require('when');
var defer = when.defer;
var error_table = require('./rpc_error_code');

// TODO: batch
function RPC_Error (code, message, data) {
    this.code = code;
    if (message) this.message = message;
    if (data) this.data = data;
}

RPC_Error.prototype.translate = function (lang) {
    return error_table[this.code][1][lang];
};

function RPC (router, send) {
    this.callbacks = { };
    this.send = send;
    this.router = router;
}

RPC.prototype.request = function (method, params, callback) {
    var req = {
        method: method,
        params: params
    };
    if (callback) {
        this.callbacks[req.id] = callback;
        req.id: uuid();
    }
    this.send(req);
};

RPC.prototype.handleResponse = function (res) {
    var callback = null;
    if (res.id) callback = this.callbacks[res.id];
    if (res.error) {
        callback(res.error);
    } else {
        callback(null, res.result);
    }
    if (res.id) delete this.callbacks[res.id];
};

RPC.prototype.handleRequest = function (req, response) {
    var func = this.router[req.method];
    if (func) {
        func(req.params, function (res) {
            if (req.id) {
                var result = { };
                result.id = req.id;
                if (res instanceof RPC_Error) {
                    result.error = res;
                } else {
                    result.result = res;
                }
                response(result);
            }
        });
    } else {
        if (req.id) {
            var result = {
                error: new RPC_Error(-32601, "Method not found", req.method),
                id: req.id
            };
            response(result);
        }
    }
};

function RabbitMQ_RPC_Client (serverAddress, user, pass, target_queue, callback) {
    var rpcClient = new RPC(null);
    var req = { credentials: amqp.credentials.plain(user, pass) };

    function handleResponse(msg) {
      var response = JSON.parse(msg.content.toString());
      rpcClient.handleResponse(response);
    }

    amqp.connect(serverAddress, req).then(function(conn) {
        return conn.createChannel().then(function(ch) {
            var ok = ch.assertQueue('', {exclusive: true})
              .then(function(qok) { return qok.queue; });

            rpcClient.close = function () { conn.close(); };
            ok = ok.then(function(queue) {
              return ch.consume(queue, handleResponse, {noAck: true})
                .then(function() { return queue; });
            });

            ok = ok.then(function(queue) {
              rpcClient.send = function (req) {
                  var config = {replyTo: queue};
                  if (req.id) config.id = req.id;
                  ch.sendToQueue(target_queue, new Buffer(JSON.stringify(req)), config);
              };
              callback(rpcClient);
            });
        });
    })
}

function RabbitMQ_RPC_Server (serverAddress, user, pass, queue, router, callback) {
    var rpcServer = new RPC(router);
    var req = { credentials: amqp.credentials.plain(user, pass) };
    amqp.connect(serverAddress, req).then(function(conn) {
      return conn.createChannel().then(function(ch) {
        rpcServer.close = function () { conn.close(); };
        var ok = ch.assertQueue(queue, {durable: false});
        var ok = ok.then(function() {
            ch.prefetch(1);
            return ch.consume(queue, reply);
        });
        return ok.then(function() {
            if (callback) callback();
        });

        function reply(msg) {
          rpcServer.handleRequest(JSON.parse(msg.content.toString()), function(res){
              ch.sendToQueue(msg.properties.replyTo,
                  new Buffer(JSON.stringify(res)),
                  {correlationId: msg.properties.correlationId});
              ch.ack(msg);
          });
        }
      });
    }).then(null, console.warn);
}

function TCP_RPC_Client (send, callback) {
    var rpcClient = new RPC(null);
    var req = { credentials: amqp.credentials.plain(user, pass) };

    function handleResponse(msg) {
      var response = JSON.parse(msg);
      rpcClient.handleResponse(response);
    }

    rpcClient.send = send;
    callback(rpcClient);
    return rpcClient;
}

function TCP_RPC_Server (port, router, onComplete) {
    var rpcServer = new RPC(router);
    var libServer = require('./server');
    var server = new libServer.Server();
    var serverConfig = {
        type: "Worker",
        port: port,
        handler: router
    };
    var appNet = gServer.startTcpServer(serverConfig);

    //TODO:
    //amqp.connect(serverAddress, req).then(function(conn) {
    //  return conn.createChannel().then(function(ch) {
    //    rpcServer.close = function () { conn.close(); };
    //    var ok = ch.assertQueue(queue, {durable: false});
    //    var ok = ok.then(function() {
    //        ch.prefetch(1);
    //        return ch.consume(queue, reply);
    //    });
    //    return ok.then(function() {
    //        if (callback) callback();
    //    });

    //    function reply(msg) {
    //      rpcServer.handleRequest(JSON.parse(msg.content.toString()), function(res){
    //          ch.sendToQueue(msg.properties.replyTo,
    //              new Buffer(JSON.stringify(res)),
    //              {correlationId: msg.properties.correlationId});
    //          ch.ack(msg);
    //      });
    //    }
    //  });
    //}).then(null, console.warn);
}
exports.RPC_Error = RPC_Error;
exports.RabbitMQ_RPC_Server = RabbitMQ_RPC_Server;
exports.RabbitMQ_RPC_Client = RabbitMQ_RPC_Client;

//TODO:
//exports.TCP_RPC_Server = TCP_RPC_Server;
//exports.TCP_RPC_Client = TCP_RPC_Client;
