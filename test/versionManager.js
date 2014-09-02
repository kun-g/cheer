var shall = require('should');
var libVersion = require('../js/versionManager');

describe('VersionManager', function () {
	var basePath = 'test/VersionManagerTest/';
	var searchPath = basePath+'update/';
	var masterPath = basePath+'base/';
	var subPath = searchPath+'master/';
	var derivedPath = searchPath+'test/';
	var fileUtil = {
		loadJSON: function (path, cb) {
			var fs = require('fs');
			fs.readFile(path, function (err, data) {
				if (err) console.log('LoadFileFail', path);
				cb(null, JSON.parse(data));
			});
		},
	};
	var versionConfig = {
		master: {
			version: '2'
		},
		test: {
			version: '3',
			parentBranch: 'master'
		}
	};
	libVersion.setFileUtil(fileUtil);

	var createManager = function () {
		var manager = new libVersion.VersionManager(versionConfig);
		manager.setRootPath(masterPath);
		manager.setSearchPath(searchPath);
		return manager;
	};

	var masterConfig = {
		"0": {
			"branch": "master",
			"version": "0",
			"path": masterPath,
			"files": [ "a.js", "dir/a.js" ]
		},
		"1": {
			"branch": "master",
			"version": "1",
			"path": subPath+"1/",
			"prevVersion": "0",
			"files" : [ "b.js", "dir/b.js", "dir/a.js" ]
		},
		"2": {
			"branch": "master",
			"version": "2",
			"path": subPath+"2/",
			"prevVersion": "1",
			"files" : [ "c.js", "dir/b.js" ]
		}
	};

	var derivedConfig = {
		"1": {
			"branch": "test",
			"version": "1",
			"path": derivedPath+"1/",
			"parentVersion" : "1",
			"files" : [ "d.js" ]
		},
		"2": {
			"branch": "test",
			"version": "2",
			"path": derivedPath+"2/",
			"prevVersion": "1",
			"files" : [ "dir/b.js", "c.js" ]
		},
		"3": {
			"branch": "test",
			"version": "3",
			"path": derivedPath+"3/",
			"prevVersion": "2",
			"parentVersion": "2",
			"files" : [ "dir/b.js" ]
		}
	};

	var tests = [
		{
			version: 0,
			config: masterConfig,
			branch: 'master',
			result: {
				"a.js": masterPath+"a.js",
				"dir/a.js": masterPath+"dir/a.js"
			}
		},
		{
			version: 1,
			config: masterConfig,
			branch: 'master',
			result: {
				"a.js": masterPath+"a.js",
				"b.js": subPath+"1/"+"b.js",
				"dir/a.js": subPath+"1/"+"dir/a.js",
				"dir/b.js": subPath+"1/"+"dir/b.js"
			}
		},
		{
			version: 2,
			config: masterConfig,
			branch: 'master',
			result: {
				"a.js": masterPath+"a.js",
				"b.js": subPath+"1/"+"b.js",
				"c.js": subPath+"2/"+"c.js",
				"dir/a.js": subPath+"1/"+"dir/a.js",
				"dir/b.js": subPath+"2/"+"dir/b.js"
			}
		},
		{
			version: 1,
			config: derivedConfig,
			baseConfig: masterConfig,
			branch: 'test',
			result: {
				"a.js": masterPath+"a.js",
				"b.js": subPath+"1/"+"b.js",
				"d.js": derivedPath+"1/"+"d.js",
				"dir/a.js": subPath+"1/"+"dir/a.js",
				"dir/b.js": subPath+"1/"+"dir/b.js"
			}
		},
		{
			version: 2,
			config: derivedConfig,
			baseConfig: masterConfig,
			branch: 'test',
			result: {
				"a.js": masterPath+"a.js",
				"b.js": subPath+"1/"+"b.js",
				"c.js": derivedPath+"2/"+"c.js",
				"d.js": derivedPath+"1/"+"d.js",
				"dir/a.js": subPath+"1/"+"dir/a.js",
				"dir/b.js": derivedPath+"2/"+"dir/b.js"
			}
		},
		{
			version: 3,
			config: derivedConfig,
			branch: 'test',
			baseConfig: masterConfig,
			result: {
				"a.js": masterPath+"a.js",
				"b.js": subPath+"1/"+"b.js",
				"c.js": derivedPath+"2/"+"c.js",
				"d.js": derivedPath+"1/"+"d.js",
				"dir/a.js": subPath+"1/"+"dir/a.js",
				"dir/b.js": derivedPath+"3/"+"dir/b.js"
			}
		}
	];


	it('init', function (done) {
		var manager = createManager();
		manager.init('test', function (err) {
			shall(manager.getVersion('master', 0)).eql(tests[0].result);
			shall(manager.getVersion('master', 1)).eql(tests[1].result);
			shall(manager.getVersion('master', 2)).eql(tests[2].result);
			shall(manager.getVersion('master', 1)).eql(tests[1].result);
			shall(manager.getVersion('test', 1)).eql(tests[3].result);
			shall(manager.getVersion('test', 2)).eql(tests[4].result);
			shall(manager.getVersion('test', 3)).eql(tests[5].result);
			done(err);
		});
	});
});
