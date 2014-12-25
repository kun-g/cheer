
generateMonitor = (obj) ->
  return (key, val) -> obj.s_attr_dirtyFlag[key] = true

class Serializer
  constructor: (data, cfg) ->
    @s_attr_to_save = []
    @s_attr_dirtyFlag = {}
    @s_attr_monitor = generateMonitor(this)
    Object.defineProperty(this, 's_attr_to_save', {enumerable:false, writable: true})
    Object.defineProperty(this, 's_attr_dirtyFlag', {enumerable:false, writable: true})
    Object.defineProperty(this, 's_attr_monitor', {enumerable:false, writable: false})

    @restore(data)

    flags = {}
    for k, v of cfg when not this[k]?
      this[k] = v
      flags[k] = true

    for k, v of cfg
      @attrSave(k, flags[k])

  destroy: () ->
    @s_attr_monitor = null

  attrSave: (key, restoreFlag = false) ->
    return false unless @s_attr_to_save.indexOf(key) is -1
    @s_attr_to_save.push(key)

  getConstructor: () -> g_attr_constructorTable[this.constructor.name]

  dump: () ->
    ret = {_constructor_: this.constructor.name, save: {}}
    for key in @s_attr_to_save
      val = @[key]
      if Array.isArray(val)
        ret.save[key] = val.map( (e) -> if e?.dump? then e.dump() else e )
      else
        ret.save[key] = if val?.dump? then val.dump() else val

    ret.save = JSON.parse(JSON.stringify(ret.save))
    return ret

  restore: (data) ->
    return @ unless data?
    if typeof data is 'string' then data = JSON.parse(data)

    for k, v of data when v?
      if v._constructor_?
        this[k] = objectlize(v)
      else if Array.isArray(v)
        this[k] = v.map( (e) -> if e?._constructor_? then objectlize(e) else  e )
      else
        this[k] = v
    return @

  dumpChanged: () ->
    ret = null
    for key in @s_attr_to_save
      ret = {} unless ret?
      if this[key].dump
        ret[key] = this[key].dump()
      else if Array.isArray(this[key])
        ret[key] = this[key].map( (v) ->
          if v?.dump then v.dump() else v
        )
      else
        ret[key] = this[key]
 
    @s_attr_dirtyFlag = {}

    if ret then ret = JSON.parse(JSON.stringify(ret)) # destroy functions
 
    return ret

objectlize  = (data) ->
  throw 'No constructor' unless data?._constructor_?
  throw 'No constructor:'+data._constructor_ unless g_attr_constructorTable[data._constructor_]
  o = new g_attr_constructorTable[data._constructor_](data.save)
  o.initialize() if o.initialize?
  return o

registerConstructor = (func, funcname) ->
  constructor = func.prototype.constructor
  funcname = constructor.name unless funcname
  g_attr_constructorTable[funcname] = func if typeof constructor is 'function'

g_attr_constructorTable = {}
exports.Serializer = Serializer
exports.registerConstructor = registerConstructor
exports.objectlize = objectlize
exports.fileVersion = -1
