//var serialLib = require('../serializer');
var dungeonLib = require('../js/dungeon');
var shall = require('should');
//require('../shared');
gServerID = 1;
initServer();

describe('Dungeon', function () {
  before(function (done) {
    initGlobalConfig(done);
  });
//
//  it('Shuffle', function () {
//    shuffle([1,2,3,4], 0).should.eql([1,2,3,4]);
//    shuffle([1,2,3,4], 1).should.eql([1,2,4,3]);
//    shuffle([1,2,3,4], 2).should.eql([1,3,2,4]);
//    shuffle([1,2,3,4], 3).should.eql([1,3,4,2]);
//  });
//
//  describe('Filter object', function () {
//    var objects = [
//      {name: 'o1', roleID: 1, health: 10, faction: 0},
//      {name: 'o2', roleID: 2, health: 11, faction: 1},
//      {name: 'o3', roleID: 3, health: 12, faction: 2},
//      {name: 'o4', roleID: 4, health: 13, faction: 3}
//    ];
//    var factionDB = {
//      0: {
//           1: {attackable: true},
//           3: {attackable: true},
//         }
//    };
//    var fo = dungeonLib.filterObject;
//    var env = {
//      getFactionConfig: function (src, tar, flag) {
//                          if (factionDB[src] == null || factionDB[src][tar] == null) return false;
//                          return factionDB[src][tar];
//                        }
//    };
//    var testThis = function (filters, names) {
//      fo(objects, filters, env).map(function (e) { return e.name; }).should.eql(names);
//    };
//    it('same-faction', function () {
//      testThis({type: 'same-faction', faction: 0}, ['o1']);
//    });
//    it('different-faction', function () {
//      testThis({type: 'different-faction', faction: 0}, ['o2', 'o3', 'o4']); 
//    });
//    it('target-faction-with-flag', function () {
//      testThis({type: 'target-faction-with-flag', faction: 0, flag: "attackable"}, ['o2', 'o4']); 
//    });
//    it('target-faction-without-flag', function () {
//      testThis({type: 'target-faction-without-flag', faction: 0, flag: "attackable"}, ['o1', 'o3']); 
//    });
//    it('source-faction-with-flag', function () {
//      testThis({type: 'source-faction-with-flag', faction: 3, flag: "attackable"}, ['o1']); 
//    });
//    it('source-faction-without-flag', function () {
//      testThis({type: 'source-faction-without-flag', faction: 3, flag: "attackable"}, ['o2', 'o3', 'o4']); 
//    });
//    it('role-id', function () { testThis({type: 'role-id', roleID: 1}, ['o1']); });
//    it('alive', function () { testThis({type: 'alive'}, ['o1', 'o2', 'o3', 'o4']); });
//    it('sort', function () { testThis({type: 'sort', by: 'health', reverse: true}, ['o4', 'o3', 'o2', 'o1']); });
//    it('count', function () { testThis({type: 'count', count: 3}, ['o1', 'o2', 'o3']); });
//  });
//
//  describe('Create units', function () {
//    it('case 1', function () {
//      var r = dungeonLib.createUnits({
//        pool: {
//                p1: [{id: 7, weight: 1}, {id: 4, weight: 1}],
//                p2: [{id: 5, weight: 1}, {id: 6, weight: 1}]
//        },
//        global: [
//          {id: 1, pos: [1,2,3], from: 0, to: 5},
//          {id: 2, property: {keyed: true}, count: 3},
//          {pool: 'p2', count: 2, levels:{ from: 3, to: 5}} 
//        ],
//        levels: [
//          [ {id: 3, count: 6}, {id: 4, from: 2, to: 5} ],
//          [ {property: {tag: 1}}, {id: 1, count: 1}, {count: 2} ],
//          [],
//          [ {pool: 'p1', count: 1} ],
//          []
//        ]
//      }, function () { return 1; });
//      r.should.eql([
//        [{id: 3, property:{}, count: 6}, {id: 4, property:{}, count: 3}],
//        [{id: 1, property: {tag: 1}, count: 1}, {id: 1, property: {tag: 1}, count: 1, pos: 2}],
//        [{id: 2, property:{keyed: true}, count: 3}],
//        [{id: 7, property:{}, count: 1}],
//        [{id: 5, property:{}, count: 1}, {id: 5, property:{}, count: 1}]
//      ]);
//    });
//  });
//
//  // TODO:Trigger command - create_unit_dungeon, create_unit_level
//  it('Faction', function (done) {
//    done();
//  });
//
//  describe('Dungeon', function () {
//    it('Test mergeFirstPace', function () {
//      var cmdStreamLib = require('../commandStream');
//      dungeonLib = require('../dungeon');
//      var cmd = dungeonLib.DungeonCommandStream({id: 'ResultCheck'});
//      cmd.getEnvironment().mergeFirstPace([], []).should.eql([]);
//      cmd.getEnvironment().mergeFirstPace([1], [1]).should.eql([[1,1]]);
//      cmd.getEnvironment().mergeFirstPace([1, 1, 1], [1]).should.eql([[1,1,1,1]]);
//      cmd.getEnvironment().mergeFirstPace([1, 1, [1]], [1]).should.eql([[1,1], 1, [1]]);
//      cmd.getEnvironment().mergeFirstPace([[1]], [1]).should.eql([[1,1]]);
//      cmd.getEnvironment().mergeFirstPace([[1], 2], [1]).should.eql([[1,1], 2]);
//      cmd.getEnvironment().mergeFirstPace([1,2,3], [4,5,6]).should.eql([[1,2,3,4,5,6]]);
//
//      //cmd.getEnvironment().mergeFirstPace([{id: ACT_ATTACK, act: 0}, {id: ACT_HURT, act: 2}], [{id: ACT_HURT, act: 0}]).should.eql([[{id: ACT_ATTACK, act: 0}, {id: ACT_HURT, act: 2}], {id: ACT_HURT, act: 0}]);
//      //console.log(cmd.getEnvironment().mergeFirstPace([1,2,3,4, [5,6,7,8]], [2,4,5]));
//    });

    it('Should be ok', function (done) {
      cmdStreamLib = require('../js/commandStream');
      d = new dungeonLib.Dungeon({
        stage: 104,
        randSeed: 1,
        abIndex: 0,
        //initialQuests: { '20': { counters: [ 0 ] },  
        //    '21': { counters: [ 0 ] } },
        team : [
          {nam: 'W', cid: 0, gen: 0, hst:0, hcl: 0, exp: 100000},
          {nam: 'M', cid: 1, gen: 0, hst:0, hcl: 0, exp: 100000},
          {nam: 'P', cid: 2, gen: 0, hst:0, hcl: 0, exp: 100000},
          //{nam: 'W1', cid: 0, gen: 0, hst:0, hcl: 0, exp:100000}
        ]
      });
      done();

      d.initialize();
//      //d.aquireCard(6);
//      //d.getHeroes()[0].attack = 10000;
      var actions = [
        {CMD:RPC_GameStartDungeon},
        {CMD:Request_DungeonExplore, arg: {tar: 11, pos:10, pos1:10, pos2:10}},
        {CMD:Request_DungeonExplore, arg: {tar: 16, pos:10, pos1:10, pos2:10}},
//        {CMD:REQUEST_CancelDungeon, arg: {}},
//
//        //{CMD:Request_DungeonCard, arg: {slt: 0}},
//        //{CMD:Request_DungeonAttack, arg: {tar: 9, pos:8, pos1:8, pos2:8}},
//        //{CMD:Request_DungeonActivate, arg: {tar: 13, pos:8, pos1:8, pos2:8}},
//
//        //{CMD:Request_DungeonExplore, arg: {tar: 13, pos:12, pos1:12, pos2:12}},
//        //{CMD:Request_DungeonExplore, arg: {tar: 14, pos:12, pos1:12, pos2:12}},
//        //{CMD:Request_DungeonActivate, arg: {tar: 14, pos:5, pos1:5, pos2:5}},
//
//        //{CMD:Request_DungeonExplore, arg: {tar: 25, pos:19, pos1:19, pos2:19}},
//        //{CMD:Request_DungeonExplore, arg: {tar: 21, pos:19, pos1:19, pos2:19}},
//        //{CMD:Request_DungeonExplore, arg: {tar: 16, pos:19, pos1:19, pos2:19}},
//        //{CMD:Request_DungeonExplore, arg: {tar: 26, pos:19, pos1:19, pos2:19}},
//        //{CMD:Request_DungeonExplore, arg: {tar: 15, pos:19, pos1:19, pos2:19}},
//        //{CMD:Request_DungeonExplore, arg: {tar: 17, pos:19, pos1:19, pos2:19}},
//        //{CMD:Request_DungeonExplore, arg: {tar: 11, pos:19, pos1:19, pos2:19}},
//        //{CMD:Request_DungeonExplore, arg: {tar: 6, pos:19, pos1:19, pos2:19}},
//        //{CMD:Request_DungeonExplore, arg: {tar: 10, pos:19, pos1:19, pos2:19}},
//        //{CMD:Request_DungeonAttack, arg: {tar: 25, pos:8, pos1:8, pos2:8}},
//        //{CMD:Request_DungeonAttack, arg: {tar: 25, pos:8, pos1:8, pos2:8}},
//        //{CMD:Request_DungeonAttack, arg: {tar: 15, pos:8, pos1:8, pos2:8}},
//        //{CMD:Request_DungeonAttack, arg: {tar: 17, pos:8, pos1:8, pos2:8}},
//        //{CMD:Request_DungeonExplore, arg: {tar: 22, pos:19, pos1:19, pos2:19}},
//        //{CMD:Request_DungeonExplore, arg: {tar: 1, pos:15, pos1:15, pos2:15}},
//        //{CMD:Request_DungeonExplore, arg: {tar: 0, pos:15, pos1:15, pos2:15}},
//        //{CMD:Request_DungeonExplore, arg: {tar: 2, pos:15, pos1:15, pos2:15}},
//        //{CMD:Request_DungeonExplore, arg: {tar: 5, pos:15, pos1:15, pos2:15}},
//        //{CMD:Request_DungeonExplore, arg: {tar: 3, pos:15, pos1:15, pos2:15}},
//        //{CMD:Request_DungeonExplore, arg: {tar: 4, pos:15, pos1:15, pos2:15}},
//        //{CMD:Request_DungeonExplore, arg: {tar: 7, pos:15, pos1:15, pos2:15}},
//        //{CMD:Request_DungeonExplore, arg: {tar: 8, pos:15, pos1:15, pos2:15}},
//        //{CMD:Request_DungeonAttack, arg: {tar: 8, pos:8, pos1:8, pos2:8}},
//        //{CMD:Request_DungeonExplore, arg: {tar: 9, pos:15, pos1:15, pos2:15}},
//        //{CMD:Request_DungeonAttack, arg: {tar: 5, pos:8, pos1:8, pos2:8}},
//        //{CMD:Request_DungeonExplore, arg: {tar: 12, pos:15, pos1:15, pos2:15}},
//        //{CMD:Request_DungeonExplore, arg: {tar: 13, pos:15, pos1:15, pos2:15}},
//        //{CMD:Request_DungeonAttack, arg: {tar: 13, pos:8, pos1:8, pos2:8}},
//        //{CMD:Request_DungeonAttack, arg: {tar: 13, pos:8, pos1:8, pos2:8}},
//        //{CMD:Request_DungeonAttack, arg: {tar: 1, pos:8, pos1:8, pos2:8}},
//        //{CMD:Request_DungeonAttack, arg: {tar: 24, pos:8, pos1:8, pos2:8}},
//        //{CMD:Request_DungeonActivate, arg: {tar: 16, pos:5, pos1:5, pos2:5}},
//
//      //{CMD:Request_DungeonExplore, arg: {tar: 20, pos:8, pos1:8, pos2:8}},
//      //{CMD:Request_DungeonExplore, arg: {tar: 25, pos:8, pos1:8, pos2:8}},
//      //{CMD:Request_DungeonExplore, arg: {tar: 15, pos:8, pos1:8, pos2:8}},
//      //{CMD:Request_DungeonExplore, arg: {tar: 16, pos:8, pos1:8, pos2:8}},
//      //{CMD:Request_DungeonExplore, arg: {tar: 26, pos:8, pos1:8, pos2:8}},
//      //{CMD:Request_DungeonExplore, arg: {tar: 27, pos:8, pos1:8, pos2:8}},
//      //{CMD:Request_DungeonExplore, arg: {tar: 11, pos:8, pos1:8, pos2:8}},
//      //{CMD:Request_DungeonExplore, arg: {tar: 10, pos:8, pos1:8, pos2:8}},
//      //{CMD:Request_DungeonExplore, arg: {tar: 12, pos:8, pos1:8, pos2:8}},
//      //{CMD:Request_DungeonSpell},
//      //{CMD:Request_DungeonAttack, arg: {tar: 12, pos:8, pos1:8, pos2:8}},
//      //{CMD:Request_DungeonAttack, arg: {tar: 12, pos:8, pos1:8, pos2:8}},
//      //{CMD:Request_DungeonExplore, arg: {tar: 7, pos:8, pos1:8, pos2:8}},
//      //{CMD:Request_DungeonActivate, arg: {tar: 7, pos:8, pos1:8, pos2:8}},
//
//      //{CMD:Request_DungeonAttack, arg: {tar: 12, pos: 17, pos1:18, pos2:19}},
//      //{CMD:Request_DungeonAttack, arg: {tar: 12, pos: 17, pos1:18, pos2:19}},
//      //{CMD:Request_DungeonAttack, arg: {tar: 12, pos: 17, pos1:18, pos2:19}},
//      //{CMD:Request_DungeonAttack, arg: {tar: 12, pos: 17, pos1:18, pos2:19}},
//
//      //{CMD:Request_DungeonCard, arg: {slt: 0}},
      ]; 
      for (var k = 0; k < actions.length-1; k++) {
        d.doAction(actions[k]);
      }
      print(d.doAction(actions[actions.length-1]));
      d.level.print();
//
//
//    x = d;
//    z = new dungeonLib.Dungeon(d.getInitialData());
//    z.actionLog = d.actionLog;
//    z.initialize();
//    //for (var k in x) {
//    //  if (!z[k] || !x[k]) console.log(k, z[k], x[k]);
//    //  z[k].should.eql(x[k])
//    //}
//    //for (var k in z) {
//    //  if (!z[k] || !x[k]) console.log(k, z[k], x[k]);
//    //  z[k].should.eql(x[k])
//    //}
//    //should(d).eql(z);
//    //print(z.doAction({CMD: RPC_GameStartDungeon}))
//
////  console.log(d.getAliveHeroes().length);
////  console.log(d.cardStack);
//
//    // All Heroes are dead
////  d.getAliveHeroes().forEach( function (h) { h.health = 0; } );
////  var cmdStreamLib = require('../commandStream');
////  var cmd = cmdStreamLib.DungeonCommandStream({id: 'ResultCheck'}, d);
////  cmd.process();
////  console.log(cmd.translate());
//    // Revive
////  cmd = cmdStreamLib.DungeonCommandStream({id: 'Revive'}, d);
////  cmd.process();
////  console.log(cmd.translate());
//
//    //setTimeout(function () {
//    //  var d = new dungeonLib.Dungeon({
//    //    stage : 76, 
//    //      infiniteLevel : 1,
//    //      team : {}
//    //  });
//    //  d.generateReward(1);
//    //  done();
//    //}, 100);
//    });
  });
});
