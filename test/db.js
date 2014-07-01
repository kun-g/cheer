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

var checkInRange = function(range,value){
  return value >= range.from && value <= range.to;
};
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
  describe('PK', function () {
    it('searchRival', function (done) {
      for (i = 0; i < 101; i++) {
        dbClient.zadd('Leaderboard.Arena', i, 'P'+i );
      }

      var arr = [
        { name: 'P6', result: [ [2, 2], [4, 5], [5, 5] ] },
        { name: 'P1', result: [ [0, 0], [2, 2], [3, 3] ] },
        { name: 'P3', result: [ [0, 0], [1, 1], [2, 2] ] },
      //  { name: 'P100', result: [ [44, 54], [81, 87], [92, 96] ] }
      ];

     async.map(arr, 
         function(e, cb) {
          dbLib.searchRival(e.name, function (err, result) {
            result[0][1].should.be.within(e.result[0][0], e.result[0][1]);
            result[1][1].should.be.within(e.result[1][0], e.result[1][1]);
            result[2][1].should.be.within(e.result[2][0], e.result[2][1]);
            cb();
          });
         }, 
         done);
    });
  });

  describe('tryAddLeaderboardMember', function () {
    var dbKey = 'Leaderboard.Test';
    before(function (done) {
      dbClient.del(dbKey, done);
    });

    it('', function (done) {
      for (i = 0; i < 10; i++) {
        dbClient.zadd(dbKey, i, 'P'+i );
      }

      var arr = [
        { board: 'Test', name: 'P6', value: 10, result: 6 },
        { board: 'Test', name: 'P10',value: 90, result: 90 },
        { board: 'Test', name: 'P6', value: null, result: 6 },
        { board: 'Test', name: 'P11',value: null, result: 11}
      ];

      async.map(arr, 
        function(e, cb) {
          dbLib.tryAddLeaderboardMember(e.board, e.name, e.value, function (err, result) {
            result.should.eql(e.result);
            cb(err);
          });
        }, 
        done);
    });
  });

});

