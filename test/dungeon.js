var dungeonLib = require('../js/dungeon');
var shall = require('should');
gServerID = 1;
initServer();

describe('Dungeon', function () {
  before(function (done) {
    initGlobalConfig('../../build/', done);
  });

  it('Shuffle', function () {
    shuffle([1,2,3,4], 0).should.eql([1,2,3,4]);
    shuffle([1,2,3,4], 1).should.eql([1,2,4,3]);
    shuffle([1,2,3,4], 2).should.eql([1,3,2,4]);
    shuffle([1,2,3,4], 3).should.eql([1,3,4,2]);
  });

  describe('Create units', function () {
    it('case 1', function () {
      var r = dungeonLib.createUnits({
        pool: {
          p1: {
            objects: [{id: 7, weight: 1}, {id: 4, weight: 1}] ,
            skill: [{id: 1, lv: 2}]

          } ,
          p2: {
            objects: [{id: 5, weight: 1}, {id: 6, weight: 1}],
            property: { keyed: true }
          }
        },
        global: [
          {id: 1, pos: [1,2,3], from: 0, to: 5},
          {id: 2, property: {keyed: true}, count: 3},
          {id: 3, count: 3, skill:[{id:1, lv:2}], levels: [0, 1, 3]},
          {pool: 'p2', count: 2, levels:{ from: 3, to: 5}} 
        ],
        levels: [
          { 
            objects: [ {id: 4, from: 2, to: 5 } ],
            skill: [{id:1, lv: 2}]
          },
          {
            objects: [ {id: 1, count: 1,skill:[{id: 4, lv: 3}]}, {count: 2} ],
            property: {tag: 1}
          },
          { objects: [ {count: 4} ] },
          { objects: [ {pool: 'p1', from:0, to: 2} ] },
          { objects: [] }
        ]
      }, function () { return 1; });
      r.should.eql([
          [ { id: 4, count: 3 ,skill :[{id:1, lv: 2}]} ],
          [ { id: 1, count: 1 ,property:{tag: 1},skill:[{id: 4, lv: 3}]},
          { id: 1, pos: 2, count: 1 ,property:{tag: 1}} ],
          [ { id: 2, count: 1 , property: {keyed: true}},
          { id: 2, count: 1 , property: {keyed: true}},
          { id: 2, count: 1 , property: {keyed: true}},
          { id: 3, count: 1 ,skill:[{id:1, lv:2}]} ],
          [ { id: 7, weight: 1,count: 1 ,skill: [{id: 1, lv: 2}]},
          { id: 3, count: 1 ,skill:[{id:1, lv:2}]},
          { id: 3, count: 1 ,skill:[{id:1, lv:2}]},],
          [ { id: 5, weight: 1, count: 1 ,property: {keyed: true}} ]
          ]);
    });
  });
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
      //d.aquireCard(6);
      //d.getHeroes()[0].attack = 10000;
    var actions = [
      {CMD:RPC_GameStartDungeon},
      {CMD:Request_DungeonExplore, arg: {tar: 11, pos:10, pos1:10, pos2:10}},
      {CMD:Request_DungeonExplore, arg: {tar: 16, pos:10, pos1:10, pos2:10}},
      {CMD:Request_DungeonExplore, arg: {tar: 21, pos:10, pos1:10, pos2:10}},
      {CMD:Request_DungeonExplore, arg: {tar: 22, pos:10, pos1:10, pos2:10}},
      {CMD:Request_DungeonExplore, arg: {tar: 23, pos:10, pos1:10, pos2:10}},
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
//    for (var k = 0; k < actions.length-1; k++) {
//      d.doAction(actions[k]);
//    }
//    print(d.doAction(actions[actions.length-1]));
//    d.level.print();
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
