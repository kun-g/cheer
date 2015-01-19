var spellLib = require('../js/spell');
var findObjWithKeyPair = spellLib.findObjWithKeyPair;
var getValidatePlayerSelectPointFilter = spellLib.getValidatePlayerSelectPointFilter;
var assert = require("assert");
var should = require('should');
describe('Spell', function () {
    var skillData = 
        [
            {
                id:1,
                targetSelection:{
                    pool:'objects',
                    filter: [],
                }
            },
            {
                id:2,
                targetSelection:{
                    testValue:'get select pool',
                    pool:'select-object',
                    filter: [],
                }
            },
            {
                id:3,
                targetSelection:{
                    testValue:'get select pool',
                    pool:'objects',
                    filter: [
                    {
                        type:'anchor',
                        anchorPos:{
                            testValue: 'in second level targetSelection',
                            pool:'select-block',
                            filter:[{
                                        type:'count',
                                        count : 1
                            }
                            ]
                        }
                    }
                    ],
                }
            },
            {
                id:4,
                targetSelection:{
                    testValue:'get select pool',
                    pool:'objects',
                    filter: [
                    {
                        type:'anchor',
                        anchorPos:{
                            pool:'blocks',
                            filter:[
                            {
                                type:'anchor',
                                anchorPos:{
                                    testValue: 'in third level targetSelection',
                                    pool:'select-block',
                                    filter:[
                                    {
                                        type:'count',
                                        count : 1
                                    }
                                        ]
                                }

                            }
                            ]
                        }
                    }
                    ],
                }
            }

        ];

    it(' findObjWithKeyPair', function() {
                
        skillData.forEach(function(e) {
            selectCfg = findObjWithKeyPair(e.targetSelection,
                {name:'pool', values:['select-object', 'select-block']})
            if (e.id == 1) {
                assert(selectCfg == null);
            }
            else{
                selectCfg.testValue.should.not.equal(null);
            }

        })

    });
    it(' getValidatePlayerSelectPointFilter ', function() {
        var objs = [
            {pos:1},{pos:2},{pos:3},{pos:4}
        ]
        env ={
            getObjects:function() {
                return objs;
            },
            getBlock:function() {
                return objs;
            }
        }
        skillData.forEach(function(e) {

            Wizard = require('../js/spell').Wizard;
            w = new Wizard();
            var ret =  getValidatePlayerSelectPointFilter(e,w, env);
            console.log(ret);
            if (e.id == 1) {
                assert(ret == null);
            }
            else{
                ret.should.equal[1,2,3,4];
            }
            console.log(ret);
        })
    });
});


//Wizard = require('../js/spell').Wizard;
//describe('Spell', function () {
//    var buffConfig = {
//        skillId: 1,
//        triggers: [
//        {
//            condition: [ {predicate: 'event', event: 'onBeDamage'} ],
//            action: [
//                {"action": "modify_variable", "key": "damage", "formular": 0},
//                {"action": "set_mutex", "mutex": "reinforce", "count": 1, target: 'SELF'}
//            ]
//        },
//        ],
//        available_condition: {predicate: 'effect_count', '#count': [1,2,3]}
//    };
//    var config = {
//        skillId: 0,
//        // tag: active_spell
//        triggers: [
//          {
//              condition: [
//                {predicate: 'cool_down', count: 10},
//                {predicate: 'event', event: 'onCastSpell', id: 0}
//              ],
//              action: [
//                  {
//                      "action": "install_spell",
//                      "spell": buffConfig,
//                      "target": "SELF",
//                      "#level": [1,2,3]
//                  },
//                  {"type":"shock", "delay":0.3, "range":5, "time":0.2}
//              ]
//          }
//        ]
//    };
//    it('install/remove spell', function () {
//        var wizard = new Wizard();
//        wizard.installSpell(config, 1);
//        wizard.wSpellDB.should.have.property('0');
//
//
//        wizard.removeSpell(config.skillId);
//        wizard.wSpellDB.should.not.have.property('0');
//    });
//
//    it('cast spell', function () {
//        var wizard = new Wizard();
//        wizard.installSpell(config, 1);
//        wizard.castSpell(config.skillId);
//        wizard.wSpellDB.should.have.property('1');
//    });

//  it('on event', function () {
//      var wizard = new Wizard();
//      wizard.installSpell(config, 1);
//      wizard.castSpell(config.skillId);
//      wizard.wSpellDB.should.have.property('1');
//      wizard.onEvent({event: 'onBeDamage', range: true, physical: true});
//      wizard.wSpellDB.should.not.have.property('1');
//  });
//});
//  var spellConfig = {
//      variable: {
//          allies_in_danger : {
//              "action": "select-target",
//              "pool": "objects",
//              "filter": [
//                  {"type":"same-faction"},
//                  {"type":"alive"},
//                  {"type":"visible"},
//                  {"type":"sort", by: "health"},
//                  {"type":"count","count":3}
//              ]
//          }
//      },
//      action: [
//        { type: 'assert-name', target: "allies_in_danger.0", name: "Hero0" },
//        { type: 'assert-name', target: "allies_in_danger.1", name: "Hero1" },
//        { type: 'assert-name', target: "allies_in_danger.2", name: "Hero2" }
//      ]
//  };
//  var cmdStreamLib = require('../js/commandStream');
//  var dungeonLib = require('../js/dungeon');
//  var heroes = [];
//  function getActiveSpell () {return 0;}
//  for (i = 0; i < 6; i ++) {
//      var h = new spellLib.Wizard();
//      h.name = 'Hero'+i;
//      h.health = i + 3;
//      h.attack = i + 10;
//      heroes.push(h);
//      h.isMonster = false;
//      h.getActiveSpell = getActiveSpell;
//  }
//  var monsters = [];
//  for (i = 0; i < 10; i++) {
//      var m = new spellLib.Wizard();
//      m.name = 'Monster'+i;
//      m.health = i + 3;
//      m.attack = i + 10;
//      monsters.push(m);
//      m.isMonster = true;
//      m.isVisible = (i % 2) == 1;
//  }

//  it ('Multiple Variable', function () {
//      var hero = heroes[0];
//      var cmd = {
//          env: {
//              vField: {},
//              getAliveHeroes: function () { return heroes; },
//              getMonsters: function () { return monsters; },
//              variable: function (k, v) {
//                  if (k) return this.vField[k];
//                  if (v) { this.vField[k] = v; return v; }
//                  return this.vField;
//              },
//          },
//          getEnvironment: function () { return this.env },
//      };
//      hero.castSpell(spellConfig, 0, cmd);
//  });
//    dprint([hero.attack,'before v',hero.wSpellDB]);
//    hero.installSpell(92,1,cmd);
//    dprint([hero.attack,'after v',hero.wSpellDB]);

//    cmd = dungeonLib.DungeonCommandStream({id: 'InitiateAttack', block:0});
//    cmd.getEnvironment = function () { return env }


//    cmd.process();
//    dprint([hero.attack,'step 1',hero.wSpellDB]);
//    cmd.process();
//    dprint([hero.attack,'step 2',hero.wSpellDB]);
//  it('spell test', function () {
//    dungeon = new dungeonLib.Dungeon({
//      stage: 0,
//            randSeed: 1,
//            team : [
//    {nam: 'W', cid: 0, gen: 0, hst:0, hcl: 0, exp: 50000},
//            {nam: 'M', cid: 1, gen: 0, hst:0, hcl: 0, exp: 50000},
//            {nam: 'P', cid: 2, gen: 0, hst:0, hcl: 0, exp: 50000},
//            {nam: 'W1', cid: 0, gen: 0, hst:0, hcl: 0, exp: 50000}
//    ]
//    });
//    dungeon.initialize();

//    var env = new dungeonLib.DungeonEnvironment(dungeon);
//    var routine = {};
//    var cmd = {
//      routine: function(c) {routine = c},
//      getEnvironment: function () { return env }
//    };
//    env.getTeammateOf = function (wizard) {
//      if (wizard.isMonster) {
//        return monsters.filter(function (m) { return m.name != wizard.name; });
//      } else {
//        return heroes.filter(function (m) { return m.name != wizard.name; });
//      }
//    };
//    env.getAliveHeroes= function() { return heroes;}
//    env.getMonsters = function() { return monsters;}
//    env.getObjectAtBlock = function(idx) {return monsters[idx];}
//    env.getHeroes = function() {return heroes;}
//    env.getObjects = function() { return heroes.concat(monsters);}
//      env.variable = function() {
//        if (this.vb == null) {
//          this.vb = {}
//        }
//        return this.vb;
//      }
      //env.getEnemyOf = function (wizard) {
      //  if (wizard.isMonster) {
      //    return heroes;
      //  } else {
      //    return monsters;
      //  }
      //};
      //var me = heroes[0];
      //var dataField = {src: heroes[0], tar: monsters[0]};
      //env.setVariableField(dataField);
      //env.rand = function () { return 0; };
      //// Target Selection
      //me.selectTarget({targetSelection: {pool:'Self', filter: ['Visible', 'Alive']}}, cmd).should.length(0);
      //me.isVisible = true;
      //var tar = me.selectTarget({targetSelection: {pool:'self', filter: ['Visible', 'Alive']}}, cmd);
      //tar[0].should.have.property('name').equal(me.name);

    //  // Trigger condition TODO:
    //  var thisSpell = {};
    //  var ret = me.triggerCheck(thisSpell, [], {}, me, cmd);
    //  ret[0].should.equal(true);
    //  ret = me.triggerCheck(null, [{'type':'countDown', 'cd': 10}], {}, me, cmd);
    //  ret[1].should.equal('NotLearned');
    //  ret = me.triggerCheck(thisSpell, [{'type':'countDown', cd: 10}], {}, me, cmd);
    //  ret[1].should.equal('NotReady');
    //  env.rand = function () { return 1; };
    //  ret = me.triggerCheck(thisSpell, [{'type':'chance', chance: 0.1}], {}, me, cmd);
    //  ret[1].should.equal('NotFortunate');
    //  env.rand = function () { return 0; };
    //  ret = me.triggerCheck(thisSpell, [{'type':'chance', chance: 0.1}], {}, me, cmd);
    //  ret[0].should.equal(true);
    //  ret = me.triggerCheck(thisSpell, [{'type':'targetMutex', mutex: 'theMutex'}], {}, [me], cmd);
    //  ret[0].should.equal(true);
    //  me.setMutex('theMutex', 1);
    //  ret = me.triggerCheck(thisSpell, [{'type':'targetMutex', mutex: 'theMutex'}], {}, [me], cmd);
    //  ret[1].should.equal('TargetMutex');
    //  ret = me.triggerCheck(thisSpell, [{'type':'card', id:0}], {}, me, cmd);
    //  ret[1].should.equal('NoCard');
    //  me.health = 11;
    //  ret = me.triggerCheck(thisSpell, [{'type':'property', property: 'health', from:0, to:10}], {}, me, cmd);
    //  ret[1].should.equal('Property');
    //  me.health = -1;
    //  ret = me.triggerCheck(thisSpell, [{'type':'property', property: 'health', from:0, to:10}], {}, me, cmd);
    //  ret[1].should.equal('Property');
    //  me.health = -1;
    //  ret = me.triggerCheck(thisSpell, [{'type':'property', property: 'health', to:10}], {}, me, cmd);
    //  ret[0].should.equal(true);

    //  // Actions TODO
    //  var actions = [ {'type': 'installSpell', spell: 1, level: 1},
    //      {'type': 'modifyVar', x: 'damage', formular: {c: 1}},
    //      {'type': 'ignoreHurt'},
    //      {'type': 'replaceTar'},
    //      {'type': 'setTargetMutex', mutex: 'TestMutex', count: 1},
    //      {'type': 'ignoreCardCost'} ];
    //  dataField.damage = 10;
    //  dataField.tar = {name: 'xxxxxx'};
    //  me.doAction(thisSpell, actions, {},[me], cmd);
    //  me.wSpellDB.should.have.property('1');
    //  dataField.damage.should.equal(1);
    //  dataField.should.have.property('ignoreHurt').equal(true);
    //  dataField.tar.should.have.property('name').equal(me.name);
    //  me.haveMutex('TestMutex').should.equal(true);
    //  dataField.should.have.property('ignoreCardCost').equal(true);
    //  me.installSpell(0, 1, cmd);
    //  me.castSpell(0, 1, cmd).should.equal(true);
    //  //me.castSpell(0, 1, cmd).should.equal('NotReady');
    //  me.doAction(thisSpell, [ {type: 'clearSpellCD'} ], {}, [me], cmd);

    //  //me.health = 10;
    //  //me.doAction(thisSpell, [ {type: 'setProperty', modifications: {health: {src: {health:1}, c:10} }} ],  {}, [me], cmd);
    //  //me.health.should.equal(30);
    //  //thisSpell.modifications.should.have.property('health').equal(20);

    //  //me.doAction(thisSpell, [ {type: 'resetProperty'} ],  {}, [me], cmd);
    //  //me.health.should.equal(10);
    //  //thisSpell.should.not.have.property('modifications');

      // install && uninstall
      //me.installSpell(1, 1, cmd);
      //me.wTriggers.should.have.property('onBePhysicalDamage').have.property('0').equal(1);
      //me.wTriggers.should.have.property('onBeSpellDamage').have.property('0').equal(1);
      //me.removeSpell(1, cmd);
      //me.wTriggers.should.not.have.property('onBeDamage');
      //me.wTriggers.should.not.have.property('onBeSpellDamage');


      //cmd = dungeonLib.DungeonCommandStream({id: 'InitiateAttack', block:0});
      //cmd.getEnvironment = function () { return env }

      //var hero = heroes[0];
      //var npc = monsters[0];
      //console.log(me,'before ====');
      //var attackBefore = npc.attack;
      //npc.installSpell(110,1,cmd);
      //npc.attack.should.eql(attackBefore/2);
      //for( var i = 0; i < 5 ; i ++) {
      //  cmd.process();
      //}
    //  npc.attack.should.eql(attackBefore);

      //me.removeSpell(110, cmd);
      //console.log(me,'removed ====');
      //me.installSpell(6, 1, cmd);
      //me.installSpell(12, 2, cmd);


    //  //var dcmd = new cmdStreamLib.DungeonCommandStream({id: 'Dialog', dialogId: 0});
    //  //me.installSpell(24, 1, dcmd);
    //  //me.ref = 0;
    //  //dcmd.print();
    //  //console.log(dcmd.translate());
    //  //should(routine).eql({id: 'SpellState', wizard: me, state: {as: BUFF_TYPE_BUFF, dc: me.attack}});

    //  // installAction && uninstallAction
    //  me.attack = 10;
    //  me.installSpell(14, 1, cmd);
    //  me.attack.should.equal(17);
    //  me.removeSpell(14, cmd);
    //  me.attack.should.equal(10);

    //  // availableCheck
    //  me.installSpell(50, 1, cmd);
    //  me.wSpellDB.should.have.property('50');
    //  me.castSpell(50, 1, cmd);
    //  me.wSpellDB.should.not.have.property('50');
    //  me.installSpell(50, 1, cmd);
    //  me.tickSpell('Battle', cmd);
    //  me.wSpellDB.should.have.property('50');
    //  me.tickSpell('Battle', cmd);
    //  me.wSpellDB.should.not.have.property('50');
    //  me.installSpell(50, 1, cmd);
    //  me.tickSpell('Move', cmd);
    //  me.wSpellDB.should.not.have.property('50');
    //});

//  describe('Real deal', function () {
//    before(function (done) {
//      dungeonLib = require('../js/dungeon');
//      dungeon = new dungeonLib.Dungeon({
//        stage: 0,
//        randSeed: 1,
//        team : [
//          {nam: 'W', cid: 0, gen: 0, hst:0, hcl: 0, exp: 50000},
//          {nam: 'M', cid: 1, gen: 0, hst:0, hcl: 0, exp: 50000},
//          {nam: 'P', cid: 2, gen: 0, hst:0, hcl: 0, exp: 50000},
//          {nam: 'W1', cid: 0, gen: 0, hst:0, hcl: 0, exp: 50000}
//        ]
//      });
//      dungeon.initialize();
//      w = dungeon.getHeroes()[0];
//      m = dungeon.getHeroes()[1];
//      p = dungeon.getHeroes()[2];
//      w1 = dungeon.getHeroes()[3];

//      done();
//    });
//    it('Specific Spell test', function () {
//      env = new dungeonLib.DungeonEnvironment(dungeon);
//      cmd = {getEnvironment: function () { return env }};
//      var dataField = {damage: 10};
//      env.setVariableField(dataField);
//      w.level.should.equal(10);
//      // Spell 0
//      w.castSpell(0, 1, cmd).should.equal(true);
//      w.wSpellDB.should.have.property('0').have.property('cd').equal(10);
//      w.castSpell(0, 1, cmd).should.equal('NotReady');
//      // Spell 1
//      w.wSpellDB.should.have.property('1').have.property('level').equal(3);
//      w.onEvent('onBePhysicalDamage', cmd);
//      dataField.damage.should.equal(0);
//      w.wSpellDB.should.have.property('1').have.property('effectCount').equal(1);
//      dataField.damage = 10;
//      w.onEvent('onBePhysicalDamage', cmd);
//      w.onEvent('onBePhysicalDamage', cmd);
//      w.onEvent('onBePhysicalDamage', cmd);
//      dataField.damage.should.equal(0);
//      w.wSpellDB.should.not.have.property('1');
//      dataField.damage = 10;
//      w.onEvent('onBePhysicalDamage', cmd);
//      dataField.damage.should.equal(10);
//      // Spell 2
//      dataField.tar = m;
//      env.rand = function () { return 0; };
//      w.onEvent('onTeammateBePhysicalDamage', cmd);
//      dataField.tar.name.should.equal('W');
//      w1.onEvent('onTeammateBePhysicalDamage', cmd);
//      dataField.tar.name.should.equal('W');
//      w.haveMutex('reinforce').should.equal(true);
//      m.haveMutex('reinforce').should.equal(true);
//      w1.wSpellDB[2].should.not.have.property('effectCount');
//      // Spell 3
//      dataField.hp = 10;
//      w.strong = 1;
//      w.onEvent('onBeHeal', cmd);
//      dataField.hp.should.equal(26);
//      // Spell 4
//      w.onEvent('onTarget', cmd);
//    });

//  });
//});
//});
//});

