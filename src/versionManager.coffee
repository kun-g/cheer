"use strict"
clone = (obj) ->
  if Array.isArray(obj)
    ret = []
  else
    ret = {}
  for k, v of obj
    ret[k] = v
  return ret

mergeFileList = (baseFileList, targetFileList) ->
  ret = clone(baseFileList)
  for k, v of targetFileList
    ret[k] = v

  return ret

fileUtil = {}
exports.setFileUtil = (aFileUtil) -> fileUtil = aFileUtil

class VersionManager
  constructor: () ->
    @fileListDB = {}
    @versionDB = {}
    @rootPath = ""
    @searchPath = ""
    @fileUtil = {}

  init: (version, cb) ->
    @initVersion(@rootPath, null, () => @initVersion(@searchPath, version, cb))

  loadVersionConfig: (basePath, version, cb) ->
    path = basePath
    path += version+'/' if version?

    ccb = (err, config) =>
      return cb(err) unless config?

      config.path = path
      @versionDB[config.version] = config

      if config.prevVersion?
        @initVersion(basePath, config.prevVersion, cb)
      else
        cb(err)

    fileUtil.loadJSON(path+'project.manifest', ccb)

  getChangeList: (fromVersion, toVersion) ->
    version = toVersion
    res = []
    while version isnt fromVersion
      versionConfig = @versionDB[version]
      unless versionConfig?.prevVersion then return []
      res = res.concat(versionConfig.files)
      version = versionConfig.prevVersion
    return res

  initVersion: (basePath, version, cb) ->
    return cb() if @getVersion(version, false)?

    @loadVersionConfig(basePath, version, cb)

  isParentVersion: (thisVersion, parentVersion) ->
    version = thisVersion
    while version isnt parentVersion
      return false unless @versionDB[version].prevVersion
      version = @versionDB[version].prevVersion

    return true

  getVersion: (version, flag) ->
    return @fileListDB[version] if @fileListDB[version]?

    versionConfig = @versionDB[version]
    return null unless versionConfig?

    path = versionConfig.path
    result = versionConfig.files.reduce(((r, e) ->
      r[e] = path+e
      return r
    ), {})

    if versionConfig.prevVersion
      result = mergeFileList(@getVersion(versionConfig.prevVersion), result)

    @fileListDB[version] = clone(result)
    if addSearchPath? and not flag then addSearchPath(path, true)
    return result

  setRootPath: (@rootPath) ->
  setSearchPath: (@searchPath) ->


exports.VersionManager = VersionManager
