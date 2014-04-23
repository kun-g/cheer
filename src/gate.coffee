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
      decoder = new SimpleProtocolDecoder()
      encoder = new SimpleProtocolEncoder()
      encoder.setFlag('size')
      c.pipe(decoder)
      c.decoder = decoder
      c.encoder = encoder
      c.server = appNet.createConnection(c)
      if not c.server? then return
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
          c = null
      )

      c.on('error', (error) ->
        console.log(error)
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
        appNet.currIndex = (appNet.currIndex + 1) % count
        return servers[(i+appNet.currIndex) % count]
      return null

    appNet.createConnection = (socket) ->
      server = getAliveConnection()
      if server?
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
      else
        socket.destroy()

      return c

    setInterval( (() ->
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
    ), 10000 )

    appNet.currIndex = 0
    appNet.server.listen(port, console.log)
    appNet.server.on('error', console.log)

  gServerID = queryTable(TABLE_CONFIG, 'ServerID')
  gServerConfig = queryTable(TABLE_CONFIG, 'ServerConfig')[gServerID]
  startTcpServer(gServerConfig.Gate, 7757)
)
