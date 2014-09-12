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
	constructor: (@branchConfig) ->
		@baseConfig = {}

		@fileListDB = {}
		@versionDB = {}
		@rootPath = ""
		@searchPath = ""
		@fileUtil = {}

		for name, config of @branchConfig
			@fileListDB[name] = {}
			@versionDB[name] = {}

	init: (branch, cb) ->
		@initMasterBranch(() =>
			@initBranch(@searchPath+branch+'/', branch, @branchConfig[branch].version, cb)
		)

	loadVersionConfig: (basePath, version, cb) ->
		path = basePath
		path += version+'/' if version?

		ccb = (err, config) =>
			return cb(err) unless config?

			config.path = path
			@versionDB[config.branch][config.version] = config

			return cb(err, @versionDB[config.branch]) unless config.prevVersion?
			return cb(err, @versionDB[config.branch]) if @versionDB[config.branch][config.prevVersion]?

			@loadVersionConfig(basePath, config.prevVersion, cb)

		fileUtil.loadJSON(path+'project.manifest', ccb)

	initBranch: (path, branch, version, cb) ->
		return cb() if @getVersion(branch, version)?

		parentBranch = @branchConfig[branch].parentBranch
		if parentBranch and not @getVersion(parentBranch, @branchConfig[parentBranch].version)?
			@initBranch(path, parentBranch, @branchConfig[parentBranch].version, () =>
				@loadVersionConfig(path, version, cb)
			)
		else
			@loadVersionConfig(path, version, cb)

	initMasterBranch: (cb) ->
		@initBranch(@rootPath, 'master', null, (err, _) =>
			@initBranch(@searchPath+'master/', 'master', @branchConfig.master.version, cb)
		)

	getVersion: (branch, version) ->
		return @fileListDB[branch][version] if @fileListDB[branch][version]?

		config = @versionDB[branch]
		return null unless config?

		versionConfig = config[version]
		return null unless versionConfig?

		path = versionConfig.path
		result = versionConfig.files.reduce(((r, e) ->
			r[e] = path+e
			return r
		), {})

		if versionConfig.prevVersion
			result = mergeFileList(@getVersion(branch, versionConfig.prevVersion), result)

		if versionConfig.parentVersion
			parentBranch = @branchConfig[branch].parentBranch
			parentVersion = versionConfig.parentVersion
			temp = @getVersion(parentBranch, parentVersion)
			result = mergeFileList(temp, result)

		@fileListDB[branch][version] = clone(result)
		if addSearchPath then addSearchPath(path, true)
		return result

	setBaseConfig: (@baseConfig) ->
	setRootPath: (@rootPath) ->
	setSearchPath: (@searchPath) ->


exports.VersionManager = VersionManager
