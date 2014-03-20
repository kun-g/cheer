require('./define')
net = require('net')
parseLib = require('./requestStream')
async = require('async')
host = 'localhost'

totalCount = 0
createTest = (id, cb) ->
  decoder = new parseLib.SimpleProtocolDecoder()
  encoder = new parseLib.SimpleProtocolEncoder()

  rpcMap = {}
  rpcCounter = 0
  makeRPC = (req, callback) ->
    totalCount++
    req.REQ = rpcCounter
    rpcMap[rpcCounter] = { cb: callback, tm: new Date() }
    rpcCounter++
    encoder.writeObject(req)

  server = net.connect({host: host, port: 7756}, () ->
    counter = id - 2
    encoder.pipe(server)
    encoder.setFlag('size')
    server.pipe(decoder)
    decoder.on('request', (request) ->
      for req in request
        if req.REQ?
          if rpcMap[req.REQ]
            rpcMap[req.REQ].cb(req)
            rpcMap[req.REQ].delay = (new Date()) - rpcMap[req.REQ].tm
        else
          #console.log(req)
    )

    #PlayerRegister
    registerHandler = (ret) ->
      if ret.RET is RET_OK
        server.destroy()
        cb()
      else
        makeRPC({CMD: 101, arg: {nam: counter.toString(), cid: rand()%3, gen: rand()%2, hst: 0, hcl: 0}}, registerHandler)
        counter++

    #PlayerLogin
    makeRPC({CMD: 100, arg: {tp: 1, id: id.toString(), tk: '1', bv: '1.0.3', rv: 98}}, (ret) ->
      if ret.RET is RET_OK
        server.destroy()
        cb()
      else
        registerHandler(ret)
    )
  )
ids = [0..1000]
start = new Date()
#async.map(ids, createTest, () ->
#  console.log('Done', totalCount, (new Date() - start))
#)

#FriendOperation

#MessageOperation

#TeamOperation

#ItemOperation

#DungeonStart

#DungeonVerify

#Chat

#DB Profile
ids = [0..100000]
GLOBAL['dbPrefix'] = 'Local.'
dbLib = require('./db')
dbLib.initializeDB({
  "Account": { "IP": "localhost", "PORT": 6379 },
  "Role": { "IP": "localhost", "PORT": 6379 },
  "Publisher": { "IP": "localhost", "PORT": 6379 },
  "Subscriber": { "IP": "localhost", "PORT": 6379 }
})
setTimeout((() -> initGlobalConfig(() ->
  async.map(ids,
    ((id, cb) -> dbLib.createNewPlayer(id, 'S', 'A'+id, cb)),
    () -> console.log('Done', (new Date() - start))
  )
)), 100)
