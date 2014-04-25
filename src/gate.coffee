{SimpleProtocolDecoder, SimpleProtocolEncoder} = require('./requestStream')
require('./define')
async = require('async')
net = require('net')

require('nodetime').profile({
  accountKey: 'c82d52d81e9ed18e8550b58bf36f49d47e50a792',
  appName: 'Gate'
})

initGlobalConfig(null, () ->
  startTcpServer = (servers, port) ->
    appNet = {}
    appNet.server = net.createServer((c) ->
      c.decoder = new SimpleProtocolDecoder()
      c.encoder = new SimpleProtocolEncoder()
      c.encoder.setFlag('size')
      c.pipe(c.decoder)
      c.server = appNet.createConnection(c)
      if not c.server? then return
      c.encoder.pipe(c.server)
      c.server.pipe(c)
      c.decoder.on('request', (request) ->
        if request
          if request.CMD is 101
            console.log({
              request: request,
              ip: c.remoteAddress
            })
          c.encoder.writeObject(request)
        else
          c.destroy()
          c = null
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
      for i in [1..count] when servers[(i+appNet.currIndex) % count].alive
        server = servers[(i+appNet.currIndex) % count]
        appNet.currIndex = (appNet.currIndex + 1) % count
        return server
      return null

    appNet.createConnection = (socket) ->
      server = getAliveConnection()
      if server?
        nc = net.connect(server.port, server.ip)
      releaseSocket = () ->
        if nc
          nc.destroy()
          nc = null
        socket.destroy()

      if nc
        nc.on('end', releaseSocket)
        nc.on('error', releaseSocket)
      socket.on('error', releaseSocket)
      socket.on('end', releaseSocket)

      return nc

    updateBackendStatus = () ->
      appNet.backends.forEach( (e) ->
        if not e.alive
          s = net.connect(e.port, e.ip)
          s.on('connect', () ->
            e.alive = true
            console.log('Connection On', e)
          )
          s.on('error', (err) -> e.alive = false)
          s.on('end', (err) ->
            e.alive = false
            console.log('Connection Lost', e)
          )
          s = null
      )

    appNet.currIndex = 0
    appNet.server.listen(port, console.log)
    appNet.server.on('error', console.log)
    updateBackendStatus()
    setInterval(updateBackendStatus, 10000)

  gServerID = queryTable(TABLE_CONFIG, 'ServerID')
  gServerConfig = queryTable(TABLE_CONFIG, 'ServerConfig')[gServerID]
  startTcpServer(gServerConfig.Gate, 7757)
)
