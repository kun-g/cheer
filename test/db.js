shall = require('should');
require('../js/define');
dbLib = require('../js/db');
async = require('async');

dbPrefix = 'Develop.';
dbIp = "10.4.3.41";

//dbPrefix = 'Local'+'.';
//dbIp = "127.0.0.1";
var shall = require('should');

gServerID = 1;
initServer();

describe('DB', function () {
  before(function (done) {
    dbLib.initializeDB({
      "Account": { "IP": dbIp, "PORT": 6379},
      "Role": { "IP": dbIp, "PORT": 6379},
      "Publisher": { "IP": dbIp, "PORT": 6379},
      "Subscriber": { "IP": dbIp, "PORT": 6379}
    }, function() {
      initGlobalConfig('../../build/', done);
    });


  });

  describe('Mercenary', function () {
    it('update', function (done) {
      var arr = [];
 //     for (i = 0; i < 10000; i++) arr.push(i);
      async.map(arr,
        function (id, cb) {
          dbClient.zadd('Leaderboard.battleforce', id, 'P'+id, cb);
        },
        function (err, result) {
          var tests = [
            { count: 1, result: ['P3'], names: ['P1', 'P2'] },
            { count: 1, result: ['P0'], names: ['P1', 'P2', 'P3'] },
            { count: 1, result: ['P4'], names: ['P0', 'P1', 'P2', 'P3'] },
            { count: 2, result: ['P4'], names: ['P0', 'P1', 'P2', 'P3'] },
          ];
          async.map(tests,
            function (t, cb) {
              dbLib.findMercenary('faruba', t.count, 30, 1, t.names, function (err, result) {
                console.log(err,result);
                shall(result.length).equal(t.count);
                result.forEach(function (e) {
                  shall(t.names.indexOf(e)).equal(-1);
                });
                cb(err);
              });
            },
            done);
        });
    });
  });

  describe('PK', function () {
    it('searchRival', function (done) {
      for (i = 200; i < 250; i++) {
        dbLib.tryAddLeaderboardMember('Arena', 'P'+i ,null, function (err, ret){
          console.log(err,ret) ;
        });
      }

      
    //  var arr = [
    //    { name: 'P6', result: [ [2, 2], [4, 5], [5, 5] ] },
    //    { name: 'P1', result: [ [0, 0], [2, 2], [3, 3] ] },
    //    { name: 'P3', result: [ [0, 0], [1, 1], [2, 2] ] },
    //  //  { name: 'P100', result: [ [44, 54], [81, 87], [92, 96] ] }
    //  ];

    // async.map(arr, 
    //     function(e, cb) {
    //      dbLib.searchRival(e.name, function (err, result) {
    //        result[0][1].should.be.within(e.result[0][0], e.result[0][1]);
    //        result[1][1].should.be.within(e.result[1][0], e.result[1][1]);
    //        result[2][1].should.be.within(e.result[2][0], e.result[2][1]);
    //        cb();
    //      });
    //     }, 
    //     done);
    });
  });

  describe('tryAddLeaderboardMember', function () {
    var dbKey = 'Leaderboard.Arena';
    before(function (done) {
      dbClient.del(dbKey, done);
    });

    it('', function (done) {
      var board = 'Arena';
      var arr = [
        { action: 'new', name: 'P0', value: null, result: 0 },
        { action: 'new', name: 'P0', value: 10, result: 0 },
        { action: 'new', name: 'P1', value: null, result: 1 },
        { action: 'new', name: 'P2', value: 90, result: 90 },
        { action: 'sweep', me: 'P2', foo: 'P0', result: 0 },
        { action: 'sweep', me: 'P2', foo: 'P0', result: 0 },
      ];

      async.mapSeries(arr, 
        function(e, cb) {
          if (e.action === 'new') {
            dbLib.tryAddLeaderboardMember(board, e.name, e.value, function (err, result) {
              result.should.eql(e.result);
              cb(err);
            });
          } else {
            dbLib.saveSocre(e.me, e.foo, function (err, result) {
              result.should.eql(e.result);
              cb(err);
            });
          }
        }, 
        done);
    });
  });

});

