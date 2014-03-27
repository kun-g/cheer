{SimpleProtocolDecoder, SimpleProtocolEncoder} = require('./requestStream')
async = require('async')
net = require('net')

startTcpServer = (servers, port) ->
  appNet = {}
  appNet.server = net.createServer((c) ->
    appNet.aliveConnections.push(c)
    c.connectionIndex = appNet.aliveConnections.length - 1
    c.pendingRequest = new Buffer(0)
    #if (config.timeout) c.setTimeout(config.timeout)
    #c.on('timeout', () -> c.end())
    c.on('end', () ->
      require("./router").peerOffline(c)
      name = c.playerName
      delete appNet.aliveConnections[c.connectionIndex]
    )
    decoder = new SimpleProtocolDecoder()
    encoder = new SimpleProtocolEncoder()
    encoder.setFlag('size')
    c.pipe(decoder)
    c.decoder = decoder
    c.encoder = encoder
    c.server = appNet.createConnection()
    encoder.pipe(c.server)
    c.server.pipe(c)
    decoder.on('request', (request) ->
      if request
        if request.CMD is 101
          console.log({
            request: request,
            ip: c.remoteAddress
          })
        encoder.writeObject(request)
      else
        c.destroy()
    )

    c.on('error', (error) ->
      console.log(error)
      c.destroy()
    )
  )
  appNet.backends = servers.map( (s, id) -> return {
    ip: s.ip,
    port: s.port,
    alive: false
  } )

  appNet.createConnection = () ->
    server = appNet.aliveServers[appNet.currIndex]
    appNet.currIndex = appNet.currIndex + 1 % appNet.aliveServers.length
    return net.connect(server)

  setInterval( (() ->
    async.map(
      appNet.backends,
      (e, cb) ->
        s = net.connect(e, () ->
          e.alive = true
          s.destroy()
          cb(null, e)
        )
        s.on('error', () ->
          e.alive = false
          s.destroy()
          cb(null, e)
        )
      ,
      (err, result) ->
        appNet.aliveServers = result.filter( (e) -> e.alive )
    )), 3000 )

  appNet.currIndex = 0
  appNet.aliveConnections = []
  appNet.server.listen(port, console.log)
  appNet.server.on('error', console.log)

startTcpServer([{ip: 'localhost', port: 7756}], 7757)
