Transform = require('stream').Transform
msgpack = require('msgpack')
crypto = require('crypto')
bson = require('bson').BSONPure.BSON
algo = 'aes128'
algoKey = '0123456789abcdef'

PACKET_FLAG_SIZE = 1
PACKET_FLAG_MESSAGEPACK = 2
PACKET_FLAG_AES = 4
PACKET_FLAG_BSON = 8

class SimpleProtocolEncoder extends Transform
  constructor: (options) ->
    @_flag = {}
    super(options)
    @totalBytes = 0
    @maxBytes = 0

  setFlag: (key, flag = true) -> @_flag[key] = flag

  onPacket: (packets) ->
    size = 0
    buffs = []
    for p in packets
      size += p.length
      buffs.push(p)
    b = Buffer(size)
    @totalBytes += size
    if size > @maxBytes then @maxBytes = size

    @write(Buffer.concat(buffs))

  writeObject: (obj) ->
    flag = 0
    buffs = []

    if @_flag.messagePack then flag |= PACKET_FLAG_MESSAGEPACK
    if @_flag.aes then flag |= PACKET_FLAG_AES
    if @_flag.size then flag |= PACKET_FLAG_SIZE
    f = Buffer(1)
    f.writeUInt8(flag, 0)
    buffs.push(f)

    if @_flag.messagePack
      data = msgpack.pack(obj)
    else if @_flag.bson
      data = bson.serialize(obj)
    else
      data = Buffer(JSON.stringify(obj))

    if @_flag.size
      f = Buffer(2)
      f.writeUInt16BE(data.length, 0)
      buffs.push(f)

    if @_flag.aes
      aes128E = crypto.createCipher(algo, algoKey)
      aes128E.on('data', (data) => @onPacket(buffs.concat([data])))
      aes128E.end(data)
    else
      @onPacket(buffs.concat([data]))

  _transform: (chunk, encoding, done) ->
    @push(chunk)
    done()

class SimpleProtocolDecoder extends Transform
  constructor: (options) ->
    @state = 'flag'
    @pendingData = Buffer(0)
    @to = 0
    @totalBytes = 0
    @maxBytes = 0
    super(options)

  onPacket: (packet) ->
    if @flag & PACKET_FLAG_MESSAGEPACK
      @emit('request', msgpack.unpack(packet))
    else if @flag & PACKET_FLAG_BSON
      @emit('request', bson.deserialize(packet))
    else
      try
        packet = JSON.parse(packet.toString())
      catch err
        packet = null
      finally
        @emit('request', packet)

  _transform: (chunk, encoding, done) ->
    from = 0
    @totalBytes += chunk.length
    data = Buffer.concat([@pendingData, chunk])
    res = null
    while @to <= data.length
      switch @state
        when 'flag'
          @flag = data.readUInt8(from)
          from += 1
          @to = from+2
          @state = 'size'
        when 'size'
          if @flag & PACKET_FLAG_SIZE
            size = data.readUInt16BE(from)
            size = Math.ceil(size/16)*16 if @flag & PACKET_FLAG_AES
            from = @to
            @to = from + size
            if size > @maxBytes then @maxBytes = size
          @state = 'data'
        when 'data'
          packet = data.slice(from, @to)
          if @flag & PACKET_FLAG_AES
            aes128D = crypto.createDecipher(algo, algoKey)
            aes128D.on('data', (res) => @onPacket(res))
            aes128D.end(packet)
          else
            @onPacket(packet)
          from = @to
          @to += 1
          @state = 'flag'

    @pendingData = data.slice(from)
    @to -= from

    done()

exports.SimpleProtocolEncoder = SimpleProtocolEncoder
exports.SimpleProtocolDecoder = SimpleProtocolDecoder
