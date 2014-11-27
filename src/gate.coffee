{SimpleProtocolDecoder, SimpleProtocolEncoder} = require('./requestStream')
require('./define')
async = require('async')
net = require('net')

startSocketIOServer = (servers, port) ->
	io = require('socket.io')
	io.listen(port).on('connection', (socket) ->
		console.log('Connection')
		socket.encoder = new SimpleProtocolEncoder()
		socket.decoder = new SimpleProtocolDecoder()
		socket.encoder.setFlag('size')
		socket.server =  backendManager.createConnection(socket)
		if not socket.server? then return
		socket.encoder.pipe(socket.server)
		socket.server.pipe(socket.decoder)
		socket.decoder.on('request', (request) ->
			socket.emit('response', request)
		)
		socket.on('request', (request) ->
			console.log('reqeust', request)
			socket.encoder.writeObject(request)
		)
	).set('log level', 0)


startTcpServer = (port, backendManager) ->
	server = net.createServer((c) ->
		c.decoder = new SimpleProtocolDecoder()
		c.encoder = new SimpleProtocolEncoder()
		c.encoder.setFlag('size')
		c.pipe(c.decoder)
		c.server =  backendManager.createConnection(c)
		if not c.server? then return
		c.encoder.pipe(c.server)
		c.server.pipe(c)
		c.decoder.on('request', (request) ->
			if request
        request.address = {
          ip: c.remoteAddress,
          port: c.remotePort
        }
        c.encoder.writeObject(request)
			else
				c.destroy()
				c = null
		)
	)
	server.listen(port, console.log)
	server.on('error', console.log)

backendManager = {
	currIndex : 0,
	backends : [],
	updateBackendStatus : () ->
		this.backends.forEach( (e) ->
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
	getAliveConnection : () ->
		count = this.backends.length
		servers = this.backends
		for i in [1..count] when servers[(i+this.currIndex) % count].alive
			server = servers[(i+this.currIndex) % count]
			this.currIndex = (this.currIndex + 1) % count
			return server
		return null
	createConnection : (socket) ->
		server = this.getAliveConnection()
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
	init : (servers) ->
		this.backends = servers.map( (s, id) -> return {
			ip: s.ip,
			port: s.port,
			alive: false
		} )
		this.updateBackendStatus()
		setInterval((() => this.updateBackendStatus()), 10000)
}

initGlobalConfig(null, () ->
	gServerID = queryTable(TABLE_CONFIG, 'ServerID')
	gServerConfig = queryTable(TABLE_CONFIG, 'ServerConfig')[gServerID]
	backendManager.init(gServerConfig.Gate)
	port =  gServerConfig.gateListenPort ? 7757
	startTcpServer(port, backendManager)
  #startSocketIOServer(backendManager, 7757)
)

