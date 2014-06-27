shall = require('should');
require('../js/define');
dbLib = require('../js/db');
async = require('async');
dbPrefix = 'Local'+'.';
dbLib.initializeDB({
  "Account": { "IP": "localhost", "PORT": 6379},
  "Role": { "IP": "localhost", "PORT": 6379},
  "Publisher": { "IP": "localhost", "PORT": 6379},
  "Subscriber": { "IP": "localhost", "PORT": 6379}
});

var shall = require('should');

gServerID = 1;
initServer();

describe('DB', function () {
  before(function (done) {
    initGlobalConfig('../../build/', done);
  });

  describe('Mercenary', function () {
    it('update', function (done) {
      var arr = [];
      for (i = 0; i < 10000; i++) arr.push(i);
      async.map(arr,
        function (id, cb) {
          dbClient.zadd('Leaderboard.battleForce', id, 'P'+id, cb);
        },
        function (err, result) {
          var tests = [
            { result: 'P3', names: ['P1', 'P2'] },
            { result: 'P0', names: ['P1', 'P2', 'P3'] },
            { result: 'P4', names: ['P0', 'P1', 'P2', 'P3'] },
            //{ result: 'P4', names: ['P0', 'P1', 'P2', 'P3', 'P4'] },
          ];
          async.map(tests,
            function (t, cb) {
              //battleforce: 2, count: 1, range: 1, delta: 1, rand: 0, 
              dbLib.findMercenary(2, 1, 1, 1, 0, t.names, function (err, result) {
                if (result === t.result) {
                  cb();
                } else {
                  cb('Fail');
                }
              });
            },
            done);
        });
    });
  });
});

