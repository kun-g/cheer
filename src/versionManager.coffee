clone = (obj) ->
	if Array.isArray(obj)
		ret = []
	else
		ret = {}
	for k, v of obj
		ret[k] = v
	return ret

mergeFileList = (baseFileList, targetFileList) ->
	for k, v of targetFileList
		baseFileList[k] = v

	return baseFileList

fileUtil = {}
exports.setFileUtil = (aFileUtil) -> fileUtil = aFileUtil

class VersionManager
	constructor: (@branchConfig) ->
		@baseConfig = {}
		@fileListDB = {}
		@currentBranch = ""
		@fileUtil = {}

		@init()

	init: () ->
		for name, config of @branchConfig
			@fileListDB[name] = {}

	setBaseConfig: (@baseConfig) ->

	generateFileList: (config, parentConfig, version, branch) ->
		if typeof parentConfig is 'number'
			version = parentConfig
			parentConfig = null

		return null unless config?
		versionConfig = config[version]
		return null unless versionConfig?

		path = versionConfig.path
		result = versionConfig.files.reduce(((r, e) ->
			r[e] = path+e
			return r
		), {})

		if versionConfig.prevVersion?
			result = mergeFileList(@generateFileList(config, parentConfig, +versionConfig.prevVersion, branch), result)

		if versionConfig.parentVersion?
			result = mergeFileList(@generateFileList(parentConfig, null, +versionConfig.parentVersion, @branchConfig[branch].parentBranch), result)

		@fileListDB[branch][version] = clone(result)
		return result

	getVersion: (branch, version) -> @fileListDB[branch][version]

	initVersion: (branch, version) -> #TODO

	initBranch: (branch) -> #TODO

	loadVersionConfig: (basePath, version, result, cb) ->
		path = basePath
		path += version+'/' if version?

		ccb = (err, config) =>
			return cb(err) unless config?

			config.path = path
			result[config.version] = config

			return cb(err, result) unless config.prevVersion?
			return cb(err, result) if result[config.prevVersion]?

			@loadVersionConfig(basePath, config.prevVersion, result, cb)

		fileUtil.loadJSON(path+'project.manifest', ccb)

	generateVersionFileList: (path, version, initialConfig, branch, cb) ->
		@loadVersionConfig(path, version, initialConfig ? {}, (err, config) =>
			cb(err, @generateFileList(config, @baseConfig, version, branch))
		)


exports.VersionManager = VersionManager
