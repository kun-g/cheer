var shall = require('should');
var libVersion = require('../js/versionManager');

describe('VersionManager', function () {
	var basePath = 'test/VersionManagerTest/';
	var searchPath = basePath+'update/';
	var masterPath = basePath+'base/';
	var subPath = searchPath+'base/';
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
		base: {
		},
		derived: {
			parentBranch: 'base',
		}
	};
	libVersion.setFileUtil(fileUtil);

	var createManager = function () {
		return new libVersion.VersionManager(versionConfig);
	};

	var masterConfig = {
		"0": {
			"version": "0",
			"path": masterPath,
			"files": [ "a.js", "dir/a.js" ]
		},
		"1": {
			"version": "1",
			"path": subPath+"1/",
			"prevVersion": "0",
			"files" : [ "b.js", "dir/b.js", "dir/a.js" ]
		},
		"2": {
			"version": "2",
			"path": subPath+"2/",
			"prevVersion": "1",
			"files" : [ "c.js", "dir/b.js" ]
		}
	};

	var derivedConfig = {
		"1": {
			"version": "1",
			"path": derivedPath+"1/",
			"parentVersion" : "1",
			"files" : [ "d.js" ]
		},
		"2": {
			"version": "2",
			"path": derivedPath+"2/",
			"prevVersion": "1",
			"files" : [ "dir/b.js", "c.js" ]
		},
		"3": {
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
			branch: 'base',
			result: {
				"a.js": masterPath+"a.js",
				"dir/a.js": masterPath+"dir/a.js"
			}
		},
		{
			version: 1,
			config: masterConfig,
			branch: 'base',
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
			branch: 'base',
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
			branch: 'derived',
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
			branch: 'derived',
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
			branch: 'derived',
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

	it('generateFileList', function () {
		var manager = createManager();
		tests.forEach(function (e) {
			shall(manager.generateFileList(e.config, e.baseConfig, e.version, e.branch)).eql(e.result);
		});
	});

	it('loadVersionConfig@sub', function (done) {
		var manager = createManager();
		manager.setBaseConfig({});
		manager.loadVersionConfig(
			subPath,
			2,
			{ "0": { "version": 0, "path": masterPath, "files": [ "a.js", "dir/a.js" ] } },
			function (err, result) {
				shall(result).eql(masterConfig);
				done();
			}
		);
	});

	it('loadVersionConfig@master', function (done) {
		var manager = createManager();
		manager.setBaseConfig({});
		manager.loadVersionConfig(
			masterPath,
			null,
			{},
			function (err, result) {
				shall(result).eql({ "0": { version: 0, path: masterPath, files: [ "a.js", "dir/a.js" ] } });
				done();
			}
		);
	});

	it('loadVersionConfig@derived', function (done) {
		var manager = createManager();
		manager.loadVersionConfig(
			derivedPath,
			3,
			{},
			function (err, result) {
				shall(result).eql(derivedConfig);
				done();
			}
		);
	});

	it('generateVersionFileList@master', function (done) {
		var manager = createManager();
		manager.setBaseConfig();
		var t = tests[2];
		manager.generateVersionFileList(
			subPath,
			t.version, 
			{ "0": { "path": masterPath, "files": [ "a.js", "dir/a.js" ] } },
			'base',
			function (err, list) {
				shall(list).eql(t.result);
				done(err);
			})
	});

	it('generateVersionFileList@derived', function (done) {
		var manager = createManager();
		manager.setBaseConfig(masterConfig);
		var t = tests[tests.length-1];
		manager.generateVersionFileList(derivedPath, t.version, {}, 'derived', function (err, list) {
			shall(list).eql(t.result);
			done(err);
		})
	});

	it('getVersion', function (done) {
		var manager = createManager();
		manager.setBaseConfig();
		manager.generateVersionFileList(
			subPath,
			2,
			{ "0": { "path": masterPath, "files": [ "a.js", "dir/a.js" ] } },
			'base',
			function (err, list) {
				shall(manager.getVersion('base', 0)).eql(tests[0].result);
				shall(manager.getVersion('base', 1)).eql(tests[1].result);
				shall(manager.getVersion('base', 2)).eql(tests[2].result);
				done(err);
			}
		);
	});
});
