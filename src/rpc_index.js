var libRPC = require('./rpc');

var RPC_Error = libRPC.RPC_Error;

var modules = [
  'organization'
];

modules.forEach(function (module) {
    console.log('Loading module %s...', module);
    var libTmp = require('./'+module);

    var prefix = libTmp.prefix;
    var router = {};
    for (var key in libTmp.router) {
        router[prefix+'.'+key] = libTmp.router[key];
    }

    libRPC.RabbitMQ_RPC_Server(
            'amqp://106.186.31.71',
            'ken',
            'tringame',
            libTmp.prefix+'_rpc',
            router,
            function () {
                console.log('Load %s done.', module);
            });
});

