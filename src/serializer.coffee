# Provide serializing mechanism

class Serializer
  constructor: () ->
    @s_attr_to_save = []
    @s_attr_version = {}
    @s_attr_dirtyFlag = {}
    Object.defineProperty(this, 's_attr_to_save', {enumerable:false})
    Object.defineProperty(this, 's_attr_version', {enumerable:false})
    Object.defineProperty(this, 's_attr_dirtyFlag', {enumerable:false})

  attrSave: (key, val) ->
    this[key] = val if val?
    return false unless @s_attr_to_save.indexOf(key) is -1
    @s_attr_to_save.push(key)

  versionControl: (versionKey, keys) ->
    keys = [keys] unless Array.isArray(keys)
    @attrSave(key) for key in keys
    this[versionKey] = 1 unless this[versionKey]?
    @s_attr_version[versionKey] = [] unless @s_attr_version[versionKey]
    @s_attr_version[versionKey].push(key) for key in keys when @s_attr_version[versionKey].indexOf(key) is -1

  getConstructor: () -> g_attr_constructorTable[this.constructor.name] # TODO:not a necessary interface

  dump: () ->
    ret = {_constructor_: this.constructor.name, save: {}}
    for key in @s_attr_to_save when @[key]?
      val = @[key]
      if Array.isArray(val)
        ret.save[key] = val.map( (e) -> if e?.dump? then e.dump() else e )
      else
        ret.save[key] = if val?.dump? then val.dump() else val

    for key, v of @s_attr_version
      ret.save[key] = this[key]

    return ret

  restore: (data) ->
    return @ unless data?

    for k, v of data when v?
      if v._constructor_?
        @attrSave(k, objectlize(v))
      else if Array.isArray(v)
        @attrSave(k, v.map( (e) -> if e?._constructor_? then objectlize(e) else  e ))
      else
        @attrSave(k, v)

    return @

  dumpChanged: () -> @dump().save
#   for key in @s_attr_to_save when this[key]? and @s_attr_dirtyFlag[key]
#     ret = {} unless ret?
#     @s_attr_dirtyFlag[key] = false
#     if this[key].dump
#       ret[key] = this[key].dump()
#     else if Array.isArray(this[key])
#       ret[key] = this[key].map( (v) ->
#         if v?.dump then v.dump() else v
#       )
#     else
#       ret[key] = this[key]

#   for key, v of @s_attr_version when ret?
#     ret[key] = this[key]

#   return ret

objectlize  = (data) ->
  throw 'No constructor' unless data?._constructor_?
  throw 'No constructor:'+data._constructor_ unless g_attr_constructorTable[data._constructor_]
  o = new g_attr_constructorTable[data._constructor_]()
  o.restore(data.save)
  o.initialize() if o.initialize?
  return o

registerConstructor = (func) ->
  constructor = func.prototype.constructor
  g_attr_constructorTable[constructor.name] = func if typeof constructor is 'function'

g_attr_constructorTable = {}
exports.Serializer = Serializer
exports.registerConstructor = registerConstructor
exports.objectlize = objectlize
exports.fileVersion = -1
