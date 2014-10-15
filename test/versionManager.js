var shall = require('should');
var libVersion = require('../js/versionManager');

describe('VersionManager', function () {
	var basePath = 'test/VersionManagerTest/';
	var searchPath = basePath+'update/';
	var masterPath = basePath+'base/';
	var subPath = searchPath+'';
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
	libVersion.setFileUtil(fileUtil);

	var createManager = function () {
		var manager = new libVersion.VersionManager();
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
		}
	];


	it('init', function (done) {
		var manager = createManager();
		manager.init(2, function (err) {
			shall(manager.getVersion(0)).eql(tests[0].result);
			shall(manager.getVersion(1)).eql(tests[1].result);
			shall(manager.getVersion(2)).eql(tests[2].result);
			shall(manager.getVersion(1)).eql(tests[1].result);
			done(err);
		});
	});
});
