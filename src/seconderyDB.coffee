"use strict"
{SimpleProtocolDecoder, SimpleProtocolEncoder} = require('./requestStream')
async = require('async')
redis = require('redis')
net = require('net')
sqlite3 = require('sqlite3').verbose()
#db = new sqlite3.Database(':memory:')
db = new sqlite3.Database('./game.db')
db.run("CREATE TABLE IF NOT EXISTS data (key text PRIMARY KEY, value TEXT);")

dbClient = redis.createClient()
startTcpServer = (port) ->
  appNet = {}
  appNet.server = net.createServer((c) ->
    c.pendingRequest = new Buffer(0)
    decoder = new SimpleProtocolDecoder()
    encoder = new SimpleProtocolEncoder()
    encoder.setFlag('size')
    c.pipe(decoder)
    c.decoder = decoder
    c.encoder = encoder
    encoder.pipe(c)
    decoder.on('request', (request) ->
      if request
        if request.CMD is 'set'
          dbClient.get(request.key, (err, value) ->
            db.parallelize(() ->
              db.exec('BEGIN;')
              stmt = db.prepare("INSERT OR REPLACE INTO data VALUES (?, ?);")
              stmt.run(request.key, value)
              stmt.finalize()
              db.exec('END;')
            )
          )
        else if request.CMD is 'get'
          db.get("SELECT value FROM data where key = '"+request.key+"';", (err, data) ->
            console.log(err, data)
            encoder.writeObject(data)
          )
      else
        c.destroy()
    )

    c.on('error', (error) ->
      console.log(error)
      c.destroy()
    )
  )

  appNet.server.listen(port, console.log)
  appNet.server.on('error', console.log)

startTcpServer(7760)
