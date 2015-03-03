
shall = require('should');
require('../js/define');
dbLib = require('../js/db');
helperLib = require('../js/helper');
async = require('async');
assert = require('assert');

//dbPrefix = 'Develop.';
//dbIp = "10.4.3.41";

dbPrefix = 'Local'+'.';
dbIp = "127.0.0.1";
var shall = require('should');

gServerID = 1;
initServer();

describe('DB', function () {
  before(function (done) {
    dbLib.initializeDB({
      "Account": { "IP": dbIp, "PORT": 6380},
      "Role": { "IP": dbIp, "PORT": 6380},
      "Publisher": { "IP": dbIp, "PORT": 6380},
      "Subscriber": { "IP": dbIp, "PORT": 6380}
    }, function() {
      done();
    });
  });

  it('deliver same message ', function(done) {
      function delMsg(name) {
          dbClient.smembers(playerMessagePrefix + name,function(err,ret) {
              for (var idx in ret) {
                  var id = ret[idx];
                  dbLib.removeMessage(name,id);
              }
          })
      }
      msg1 = {type:1, text: 'this is a msg'};
      msg2 = {type:1, text: 'this is another msg'};
      msg3 = {type:1, text: 'this is third msg'};
      function checkf(ret, checkValue) {
          assert(Array.isArray(ret), 'should be an array');
          assert(ret.length == checkValue.length, 'length equal');
      }
      var data = [
      { data:msg1, u:false,check:checkf, checkValue:{length:1}},
      { data:msg1, u:false,check:checkf, checkValue:{length:2}},
      { data:msg2, u:false,check:checkf, checkValue:{length:3}},
      { data:msg1, u:true, check:checkf, checkValue:{length:3}},
      { data:msg3, u:true, check:checkf, checkValue:{length:4}},
      ];
      var name = 'faruba';
      delMsg('faruba');
      async.eachSeries(data,function(e,cb) {
          dbLib.deliverMessage(name, e.data, function(err,ret) {
              dbLib.fetchMessage(name, function(err, msg) {
                  e.check(msg, e.checkValue);
                  cb();
              });
          }, null, e.u);

      }, function(err){
          done();
      })

  });

  /*
  describe('Mercenary', function () {
    it('update', function (done) {
      var arr = [1,2,3,4,5,6,7,8,9,10];
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
              dbLib.findMercenary('P1', t.count, 30, 1, t.names, function (err, result) {
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
      for (var i = 0; i < 250; i++) {
        dbLib.tryAddLeaderboardMember('Arena', 'P'+i , i);
      }

      var arr = [
        { name: 'P6', result: [ [2, 2], [4, 5], [5, 5] ] },
        { name: 'P1', result: [ [0, 0], [2, 2], [3, 3] ] },
        { name: 'P3', result: [ [0, 0], [1, 1], [2, 2] ] },
        //{ name: 'P100', result: [ [44, 54], [81, 87], [92, 96] ] }
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

  describe('updateReceipt', function () {
    it('basic', function (done) {
      var receipt = '0000553801011405638359AppStore';
      function shouldBeOne(err, result) { result.should.eql(1); }
      function shouldBeZero(err, result) { result.should.eql(0); }
      async.series([
        function (cb) {
          accountDBClient.del('Receipt.'+receipt, cb);
        },
        function (cb) {
          dbLib.updateReceipt(receipt, 'New', 5538, 1, 1, 'AppStore', helperLib.currentTime(true),
            function (err, result) {
              result.should.eql('New');
              accountDBClient.sismember('receipt_index_by_state:'+'New', receipt, shouldBeOne);
              cb(err);
            });
        },
        function (cb) {
          dbLib.updateReceipt(receipt, 'Old', 5538, 1, 1, 'AppStore', helperLib.currentTime(true),
            function (err, result) {
              result.should.eql('Old');
              accountDBClient.sismember('receipt_index_by_state:'+'Old', receipt, shouldBeOne);
              accountDBClient.sismember('receipt_index_by_state:'+'New', receipt, shouldBeZero);
              cb(err);
            });
        },
        function (cb) {
          var m = helperLib.currentTime(true);
          var year = m.year();
          var month = m.month();
          var day = m.date();
          accountDBClient.sismember('receipt_index_by_time:'+year+'_'+month+'_'+day, receipt, shouldBeOne);
          accountDBClient.sismember('receipt_index_by_time:'+year+'_'+month+'_'+day, receipt, shouldBeOne);
          accountDBClient.sismember('receipt_index_by_id:'+5538, receipt, shouldBeOne);
          accountDBClient.sismember('receipt_index_by_product:'+1, receipt, shouldBeOne);
          accountDBClient.sismember('receipt_index_by_tunnel:'+'AppStore', receipt, shouldBeOne);
          accountDBClient.sismember('receipt_index_by_server:'+1, receipt, shouldBeOne);
          cb();
        }
      ], done);
    });
  });
*/
});

