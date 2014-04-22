{SimpleProtocolDecoder, SimpleProtocolEncoder} = require('./requestStream')
require('./define')
async = require('async')
net = require('net')

initGlobalConfig(null, () ->
  startTcpServer = (servers, port) ->
    appNet = {}
    appNet.server = net.createServer((c) ->
      appNet.aliveConnections.push(c)
      c.connectionIndex = appNet.aliveConnections.length - 1
      c.pendingRequest = new Buffer(0)
      #if (config.timeout) c.setTimeout(config.timeout)
      #c.on('timeout', () -> c.end())
      c.on('end', () ->
        delete appNet.aliveConnections[c.connectionIndex]
      )
      decoder = new SimpleProtocolDecoder()
      encoder = new SimpleProtocolEncoder()
      encoder.setFlag('size')
      c.pipe(decoder)
      c.decoder = decoder
      c.encoder = encoder
      c.server = appNet.createConnection(c)
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

    getAliveConnection = () ->
      count = appNet.backends.length
      servers = appNet.backends
      for i in [1..count] when servers[i+appNet.currIndex % servers.length].alive
        appNet.currIndex = appNet.currIndex + 1 % appNet.aliveServers.length
        return servers[i+appNet.currIndex % servers.length]
      return null

    appNet.createConnection = (socket) ->
      server = getAliveConnection()
      c = net.connect(server.port, server.ip)
      c.on('error', (err) ->
        c.destroy()
        socket.destroy()
        c = null
      )
      c.on('end', (err) ->
        c.destroy()
        socket.destroy()
        c = null
      )

      return c

    setInterval( (() ->
      appNet.backends.forEach( (e) ->
        if not e.alive
          s = net.connect(e.port, e.ip)
          s.on('connect', () ->
            console.log('Connection On', e)
            e.alive = true
          )
          s.on('end', (err) ->
            console.log('Connection Lost', e)
            e.alive = false
          )
          s = null
      )
    ), 10000 )

    appNet.currIndex = 0
    appNet.server.listen(port, console.log)
    appNet.server.on('error', console.log)

  gServerID = queryTable(TABLE_CONFIG, 'ServerID')
  gServerConfig = queryTable(TABLE_CONFIG, 'ServerConfig')[gServerID]
  startTcpServer(gServerConfig.Gate, 7757)
)
