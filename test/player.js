shall = require('should');
//var assert = require("assert");
//var playerLib = require('../player');
//var dbLib = require('../db');
//var serialLib = require('../serializer');
var dungeonLib = require('../js/dungeon');
//var should = require('should');
var spellLib = require('../js/spell');
//var itemLib = require('../item');
//require('../define');
//require('../shared');
//initServer();
//gServerName = 'UnitTest';
//gServerID = 1;
//dbPrefix = gServerName+'.';
//dbLib.initializeDB({
//  "Account": { "IP": "localhost", "PORT": 6379},
//  "Role": { "IP": "localhost", "PORT": 6379},
//  "Publisher": { "IP": "localhost", "PORT": 6379},
//  "Subscriber": { "IP": "localhost", "PORT": 6379}
//});
//
//var playerName = 'unitTestQ';
//var othersName = 'pawn';
//var countOfOthers = 30;
//logLevel = 1;
//var handlers = require('../commandHandlers').route;
//
describe('', function () {
  before(function (done) {
    initGlobalConfig('../build/', function () {
      console.log(queryTable(TABLE_CONFIG,  'Global_Material_ID'));
      done();
    });
  });
//  after(function () {
//    dbLib.releaseDB();
//  });
//
//  //describe('Auth', function () {
//  //  it('Bind and verify', function (done) {
//  //    async.series([
//  //      function (cb) { dbLib.bindAuth(0, 'test', 'test', cb); },
//  //      function (cb) { dbLib.verifyAuth('test', 'test', cb); },
//  //    ], done);
//  //  });
//  //});
//
//  describe('SimpleProtocol', function () {
//    var parseLib = require('../requestStream');
//    var encoder = new parseLib.SimpleProtocolEncoder();
//    var decoder = new parseLib.SimpleProtocolDecoder();
//
//    it('Should work with message pack & AES', function (done) {
//      encoder.setFlag('messagePack');
//      encoder.setFlag('size');
//      encoder.pipe(decoder);
//      var count = 6;
//      decoder.on('request', function (req) {
//        should(req).eql({a: '123'});
//        count--;
//        if (count === 0) done();
//      });
//      encoder.setFlag('aes');
//      encoder.writeObject({a: '123'});
//      encoder.writeObject({a: '123'});
//      encoder.setFlag('aes', false);
//      encoder.writeObject({a: '123'});
//      encoder.writeObject({a: '123'});
//      encoder.setFlag('aes', true);
//      encoder.writeObject({a: '123'});
//      encoder.setFlag('bson', true);
//      encoder.writeObject({a: '123'});
//      encoder.setFlag('bson', true);
//      encoder.writeObject({a: '123'});
//    });
//  });
//
//  describe('Serializer', function () {
//    var test = new serialLib.Serializer();
//    test.attrSave('pNumber', 1);
//    test.attrSave('pString', 'init');
//    test.attrSave('pObject', {foo: 'bar', t: {foo: 'bar'}});
//    test.attrSave('pArray', [1,2,3]);
//    test.versionControl('version', ['pNumber', 'pString', 'pObject', 'pArray']);
//    serialLib.registerConstructor(serialLib.Serializer);
//
//    it('Should restore from dumped data.', function () {
//      test.pNumber = 2;
//      test.pString = 'data';
//      test.pObject.foo = 'bar1';
//      var tmp = serialLib.objectlize(test.dump());
//      should(test.dump()).eql(tmp.dump());
//      //should(test.dumpChanged()).eql(test.dump().save);
//      //should(test.dumpChanged()).equal(undefined);
//      test.pObject.t = {foo: 'barT'};
//      //should(test.dumpChanged()).eql({pObject: {foo: 'bar1', t: {foo: 'barT'}}, version: 6});
//      test.pArray.push(4);
//      //should(test.dumpChanged()).eql({pArray: [1,2,3,4], version: 7});
//    });
//  });
//
  describe('CommandStream', function () {
    var cmdLib = require('../js/commandStream');
    it('Should work with this test run', function () {
      var cmdConfig = {
        someThing: { callback: function (cmd) { }, output: function (cmd) { return 'Some'; } },
        otherThing: { callback: function (cmd) { }, output: function (cmd) { return 'Other'; } },
        addNextThing: { callback: function (cmd) { this.routine({id:'nextThing'}); }, output: function (cmd) { return 'addNext'; } },
        nextThing: { callback: function (cmd) { this.next({id:'anotherThing'}); }, output: function (cmd) { return 'Next'; } },
        anotherThing: { callback: function (cmd) { }, output: function (cmd) { return 'Another'; } }
      };
      var cmd = new cmdLib.CommandStream({id: 'someThing'}, null, cmdConfig);
      cmd.next({id: 'addNextThing'})
         .next({id: 'otherThing'});
      cmd.process();
    });
  });

  describe('Spell', function () {
    var cmdStreamLib = require('../js/commandStream');
    var heroes = [];

    function getActiveSpell () {return 0;}
    for (i = 0; i < 6; i ++) {
      var h = new spellLib.Wizard();
      h.name = 'Hero'+i;
      h.health = i + 3;
      h.attack = i + 1;
      heroes.push(h);
      h.isMonster = false;
      h.getActiveSpell = getActiveSpell;
    }
    var monsters = [];
    for (i = 0; i < 10; i++) {
      var m = new spellLib.Wizard();
      m.name = 'Monster'+i;
      m.health = i + 3;
      m.attack = i + 1;
      monsters.push(m);
      m.isMonster = true;
      m.isVisible = (i % 2) == 1;
    }

    it('should pass this test run', function () {
      var env = new dungeonLib.DungeonEnvironment(null);
      var routine = {};
      var cmd = {
        routine: function(c) {routine = c},
        getEnvironment: function () { return env }
      };
      env.getTeammateOf = function (wizard) {
        if (wizard.isMonster) {
          return monsters.filter(function (m) { return m.name != wizard.name; });
        } else {
          return heroes.filter(function (m) { return m.name != wizard.name; });
        }
      };
      env.getEnemyOf = function (wizard) {
        if (wizard.isMonster) {
          return heroes;
        } else {
          return monsters;
        }
      };
      var me = heroes[0];
      var dataField = {src: heroes[0], tar: monsters[0]};
      env.setVariableField(dataField);
      env.rand = function () { return 0; };
      // Target Selection
      me.selectTarget({targetSelection: {pool:'Self', filter: ['Visible', 'Alive']}}, cmd).should.length(0);
      me.isVisible = true;
      var tar = me.selectTarget({targetSelection: {pool:'Self', filter: ['Visible', 'Alive']}}, cmd);
      tar[0].should.have.property('name').equal(me.name);
      tar = me.selectTarget({targetSelection: {pool:'Team', method: ['Rand']}}, cmd);
      tar[0].should.have.property('name').equal(heroes[1].name);
      tar = me.selectTarget({targetSelection: {pool:'Enemy', filter: ['Visible']}}, cmd);
      tar.should.length(5);
      tar = me.selectTarget({targetSelection: {pool:'Enemy', filter: ['Visible'], method: ['LowHealth']}}, cmd);
      tar[0].should.have.property('name').equal(monsters[1].name);

      // Trigger condition TODO:
      var thisSpell = {};
      var ret = me.triggerCheck(thisSpell, [], {}, me, cmd);
      ret[0].should.equal(true);
      ret = me.triggerCheck(null, [{'type':'countDown', 'cd': 10}], {}, me, cmd);
      ret[1].should.equal('NotLearned');
      ret = me.triggerCheck(thisSpell, [{'type':'countDown', cd: 10}], {}, me, cmd);
      ret[1].should.equal('NotReady');
      env.rand = function () { return 1; };
      ret = me.triggerCheck(thisSpell, [{'type':'chance', chance: 0.1}], {}, me, cmd);
      ret[1].should.equal('NotFortunate');
      env.rand = function () { return 0; };
      ret = me.triggerCheck(thisSpell, [{'type':'chance', chance: 0.1}], {}, me, cmd);
      ret[0].should.equal(true);
      ret = me.triggerCheck(thisSpell, [{'type':'targetMutex', mutex: 'theMutex'}], {}, [me], cmd);
      ret[0].should.equal(true);
      me.setMutex('theMutex', 1);
      ret = me.triggerCheck(thisSpell, [{'type':'targetMutex', mutex: 'theMutex'}], {}, [me], cmd);
      ret[1].should.equal('TargetMutex');
      ret = me.triggerCheck(thisSpell, [{'type':'card', id:0}], {}, me, cmd);
      ret[1].should.equal('NoCard');
      me.health = 11;
      ret = me.triggerCheck(thisSpell, [{'type':'property', property: 'health', from:0, to:10}], {}, me, cmd);
      ret[1].should.equal('Property');
      me.health = -1;
      ret = me.triggerCheck(thisSpell, [{'type':'property', property: 'health', from:0, to:10}], {}, me, cmd);
      ret[1].should.equal('Property');
      me.health = -1;
      ret = me.triggerCheck(thisSpell, [{'type':'property', property: 'health', to:10}], {}, me, cmd);
      ret[0].should.equal(true);

      // Actions TODO
      var actions = [ {'type': 'installSpell', spell: 1, level: 1},
          {'type': 'modifyVar', x: 'damage', formular: {c: 1}},
          {'type': 'ignoreHurt'},
          {'type': 'replaceTar'},
          {'type': 'setTargetMutex', mutex: 'TestMutex', count: 1},
          {'type': 'ignoreCardCost'} ];
      dataField.damage = 10;
      dataField.tar = {name: 'xxxxxx'};
      me.doAction(thisSpell, actions, {},[me], cmd);
      me.wSpellDB.should.have.property('1');
      dataField.damage.should.equal(1);
      dataField.should.have.property('ignoreHurt').equal(true);
      dataField.tar.should.have.property('name').equal(me.name);
      me.haveMutex('TestMutex').should.equal(true);
      dataField.should.have.property('ignoreCardCost').equal(true);
      me.installSpell(0, 1, cmd);
      me.castSpell(0, 1, cmd).should.equal(true);
      //me.castSpell(0, 1, cmd).should.equal('NotReady');
      me.doAction(thisSpell, [ {type: 'clearSpellCD'} ], {}, [me], cmd);

      //me.health = 10;
      //me.doAction(thisSpell, [ {type: 'setProperty', modifications: {health: {src: {health:1}, c:10} }} ],  {}, [me], cmd);
      //me.health.should.equal(30);
      //thisSpell.modifications.should.have.property('health').equal(20);

      //me.doAction(thisSpell, [ {type: 'resetProperty'} ],  {}, [me], cmd);
      //me.health.should.equal(10);
      //thisSpell.should.not.have.property('modifications');

      // install && uninstall
      me.installSpell(1, 1, cmd);
      me.wTriggers.should.have.property('onBePhysicalDamage').have.property('0').equal(1);
      me.wTriggers.should.have.property('onBeSpellDamage').have.property('0').equal(1);
      me.removeSpell(1, cmd);
      me.wTriggers.should.not.have.property('onBeDamage');
      me.wTriggers.should.not.have.property('onBeSpellDamage');
      me.installSpell(6, 1, cmd);
      me.installSpell(12, 2, cmd);


      //var dcmd = new cmdStreamLib.DungeonCommandStream({id: 'Dialog', dialogId: 0});
      //me.installSpell(24, 1, dcmd);
      //me.ref = 0;
      //dcmd.print();
      //console.log(dcmd.translate());
      //should(routine).eql({id: 'SpellState', wizard: me, state: {as: BUFF_TYPE_BUFF, dc: me.attack}});

      // installAction && uninstallAction
      me.attack = 10;
      me.installSpell(14, 1, cmd);
      me.attack.should.equal(17);
      me.removeSpell(14, cmd);
      me.attack.should.equal(10);

      // availableCheck
      me.installSpell(50, 1, cmd);
      me.wSpellDB.should.have.property('50');
      me.castSpell(50, 1, cmd);
      me.wSpellDB.should.not.have.property('50');
      me.installSpell(50, 1, cmd);
      me.tickSpell('Battle', cmd);
      me.wSpellDB.should.have.property('50');
      me.tickSpell('Battle', cmd);
      me.wSpellDB.should.not.have.property('50');
      me.installSpell(50, 1, cmd);
      me.tickSpell('Move', cmd);
      me.wSpellDB.should.not.have.property('50');
    });

    describe('Real deal', function () {
      before(function (done) {
        dungeonLib = require('../js/dungeon');
        dungeon = new dungeonLib.Dungeon({
          stage: 0,
          randSeed: 1,
          team : [
            {nam: 'W', cid: 0, gen: 0, hst:0, hcl: 0, exp: 50000},
            {nam: 'M', cid: 1, gen: 0, hst:0, hcl: 0, exp: 50000},
            {nam: 'P', cid: 2, gen: 0, hst:0, hcl: 0, exp: 50000},
            {nam: 'W1', cid: 0, gen: 0, hst:0, hcl: 0, exp: 50000}
          ]
        });
        dungeon.initialize();
        w = dungeon.getHeroes()[0];
        m = dungeon.getHeroes()[1];
        p = dungeon.getHeroes()[2];
        w1 = dungeon.getHeroes()[3];

        done();
      });
      it('Specific Spell test', function () {
        env = new dungeonLib.DungeonEnvironment(dungeon);
        cmd = {getEnvironment: function () { return env }};
        var dataField = {damage: 10};
        env.setVariableField(dataField);
        w.level.should.equal(10);
        // Spell 0
        w.castSpell(0, 1, cmd).should.equal(true);
        w.wSpellDB.should.have.property('0').have.property('cd').equal(10);
        w.castSpell(0, 1, cmd).should.equal('NotReady');
        // Spell 1
        w.wSpellDB.should.have.property('1').have.property('level').equal(3);
        w.onEvent('onBePhysicalDamage', cmd);
        dataField.damage.should.equal(0);
        w.wSpellDB.should.have.property('1').have.property('effectCount').equal(1);
        dataField.damage = 10;
        w.onEvent('onBePhysicalDamage', cmd);
        w.onEvent('onBePhysicalDamage', cmd);
        w.onEvent('onBePhysicalDamage', cmd);
        dataField.damage.should.equal(0);
        w.wSpellDB.should.not.have.property('1');
        dataField.damage = 10;
        w.onEvent('onBePhysicalDamage', cmd);
        dataField.damage.should.equal(10);
        // Spell 2
        dataField.tar = m;
        env.rand = function () { return 0; };
        w.onEvent('onTeammateBePhysicalDamage', cmd);
        dataField.tar.name.should.equal('W');
        w1.onEvent('onTeammateBePhysicalDamage', cmd);
        dataField.tar.name.should.equal('W');
        w.haveMutex('reinforce').should.equal(true);
        m.haveMutex('reinforce').should.equal(true);
        w1.wSpellDB[2].should.not.have.property('effectCount');
        // Spell 3
        dataField.hp = 10;
        w.strong = 1;
        w.onEvent('onBeHeal', cmd);
        dataField.hp.should.equal(26);
        // Spell 4
        w.onEvent('onTarget', cmd);
      });

    });
  });
//
//  describe('Player', function () {
//    after(function (done) {
//      function generator (name) { 
//        return function (cb) {
//          var dbWrapper = require('../dbWrapper');
//          dbLib.removePlayer(name, cb);
//          dbWrapper.removeMercenaryMember(75, name);
//          dbWrapper.removeMercenaryMember(0, name);
//        };
//      }
//      var quests = [ generator(playerName)];
//
//      for (var i = 0; i < countOfOthers; i++) {
//        quests.push(generator(othersName+i));
//      }
//      async.parallel(quests, done);
//    });
//
//    describe('#playerMessageFilter', function () {
//      var newMessage = [];
//      var message1 = [
//        {messageID: 0}, {messageID: 1}, {messageID: 2}, {messageID: 3},
//        {messageID: 4, name: '1', type: Event_FriendApplication},
//        {messageID: 5, name: '1', type: Event_FriendApplication},
//        {messageID: 6, name: '2', type: Event_FriendApplication}
//      ];
//      var message2 = message1.concat([
//          {messageID: 7, name: '1', type: Event_FriendApplication},
//          {messageID: 8, name: '3', type: Event_FriendApplication},
//          {messageID: 9, name: '3', type: Event_FriendApplication}
//        ]);
//      newMessage = playerLib.playerMessageFilter([], message1);
//      newMessage.should.length(6);
//      newMessage = playerLib.playerMessageFilter(newMessage, message2);
//      newMessage.should.length(1);
//    });
//
//    describe('#packQuestEvent', function (done) {
//      var quests = [{counters:[1,2,3,4]}];
//      packQuestEvent(quests, 0, 0).should.have.property('NTF').equal(Event_UpdateQuest);
//      packQuestEvent(quests, 0, 0).should.have.property('arg');
//      packQuestEvent(quests, 0, 0).arg.should.have.property('qst').length(1);
//      packQuestEvent(quests, 0, 0).arg.qst[0].should.have.property('cnt').length(4);
//      packQuestEvent(quests, 0, 0).arg.should.have.property('syn').equal(0);
//      packQuestEvent(quests, null, 0).arg.should.have.property('syn').equal(0);
//      packQuestEvent(quests, null).arg.should.not.have.property('syn');
//    });
//
//    describe('#incrBlustarBy', function () {
//      function generator (count) {
//        return function (cb) {
//          dbLib.incrBluestarBy(playerName, count, cb);
//        };
//      }
//      var quests = [];
//      for (var i = 0; i < countOfOthers; i++) {
//        quests.push(generator(i));
//      }
//      for (i = 0; i < countOfOthers; i++) {
//        quests.push(generator(-i));
//      }
//      async.parallel(quests, function (err, results) {
//        dbLib.incrBluestarBy(playerName, 0, function (err, num) {
//          if (num !== 0) err = new Error('It should be zero');
//        });
//      });
//    });
//
//    describe('#Creation', function () {
//      it('Should reject invalid name', function (done) {
//        dbLib.createNewPlayer(null, null, 'me?no', function (err) {
//          if (err.message == RET_InvalidName) {
//            done();
//          } else {
//            done(err);
//          }
//        });
//      });
//      it('Should be ok with these names', function (done) {
//        function generator (name) { 
//          return function (cb) {
//            dbLib.createNewPlayer(null, null, name, cb); 
//          };
//        }
//        var quests = [function (cb) { dbLib.createNewPlayer(null, null, playerName, cb); }];
//        for (var i = 0; i < countOfOthers; i++) quests.push(generator(othersName+i));
//        async.parallel(quests, done);
//      });
//      it('Should reject another creation with name '+playerName, function (done) {
//        dbLib.createNewPlayer(null, null, playerName, function (err) {
//          if (err.message == RET_NameTaken) {
//            done();
//          } else {
//            done(new Error(1));
//          }
//        });
//      });
//      it('Should be loaded without exception', function (done) {
//        function generator (name) { 
//          return function (cb) {
//            dbLib.loadPlayer(name, cb); 
//          };
//        }
//        var quests = [function (cb) { dbLib.loadPlayer(playerName, cb); }];
//        for (var i = 0; i < countOfOthers; i++) quests.push(generator(othersName+i));
//        async.parallel(quests, done);
//      });
//
//      it('Should be ok with packQuestEvent', function (done) {
//        dbLib.loadPlayer(playerName, function (err, p) {
//          p.syncQuest().arg.should.have.property('syn').equal(p.questVersion);
//          p.syncQuest(true).arg.should.have.property('clr').equal(true);
//          done(err);
//        });
//      });
//    });
//
//    describe('#DBOperation', function () {
//      describe('#Friend', function () {
//        var othername = othersName+0;
//        it('Should make them friends', function (done) {
//          async.series([
//            function (cb) { dbLib.makeFriends(playerName, othername, cb); },
//            function (cb) { dbLib.getFriendList(playerName, cb); },
//            function (cb) { dbLib.getFriendList(othername, cb); }
//            ],
//            function (err, result) {
//              if (err) done(err);
//              if (result[1].book.indexOf(othername) == -1 || 
//                result[2].book.indexOf(playerName) == -1) {
//                  err = new Error('data lost');
//                }
//              done(err);
//            });
//        });
//        it('Should break them up', function (done) {
//          dbLib.removeFriend(playerName, othername, done);
//        });
//        it('Should reject the 21st one', function (done) {
//          function generator (id) {
//            return function (cb) {
//              dbLib.makeFriends(playerName, othersName+id, cb);
//            };
//          }
//          var quests = [];
//          for (var i = 0; i < countOfOthers; i++) {
//            quests.push(generator(i));
//          }
//          async.series(quests, function (err, result) {
//            if (result.length == 21) {
//              done();
//            } else {
//              done(err);
//            }
//          });
//        });
//        it('Should break them up, again', function (done) {
//          function generator (id) {
//            return function (cb) {
//              dbLib.removeFriend(playerName, othersName+id, cb);
//            };
//          }
//          var quests = [];
//          for (var i = 0; i < countOfOthers; i++) {
//            quests.push(generator(i));
//          }
//          async.parallel(quests, done);
//        });
//      });
//      describe('#Message', function () {
//        it('Should complete without errors', function (done) {
//          async.series([
//            function (cb) { dbLib.fetchMessage(playerName, cb); },
//            function (cb) { dbLib.deliverMessage(playerName, {type:123, data:345}, cb); },
//            function (cb) { dbLib.fetchMessage(playerName, cb); },
//            function (cb) { dbLib.deliverMessage(playerName, {type:123, data:345}, cb); }
//            ], done);
//        });
//        it('Should have what has been deliverred', function (done) {
//          var prevCount = 0;
//          dbLib.loadPlayer(playerName, function (err, p) {
//            async.series([
//                function (cb) { dbLib.deliverMessage(playerName, {type:123}, cb); },
//                function (cb) { p.fetchMessage(cb); },
//                function (cb) { dbLib.deliverMessage(playerName, {type:123}, cb); },
//                function (cb) { p.fetchMessage(function (err, lst) {
//                    lst.should.length(1);
//                    cb(err, lst);
//                  });
//                },
//                function (cb) { dbLib.deliverMessage(playerName, {type:123}, cb); },
//                function (cb) { dbLib.deliverMessage(playerName, {type:123}, cb); },
//                function (cb) { p.fetchMessage(function (err, lst) {
//                    lst.should.length(2);
//                    cb(err, lst);
//                  });
//                }
//              ], done);
//          });
//        });
//
//        it('Should fetch the message', function (done) {
//          dbLib.subscribe('TestChannel', function (msg) {
//            var err = null;
//            if (msg != 'Hello pubsub') err = new Error('Lost');
//            done(err, msg);
//          });
//          dbLib.publish('TestChannel', 'Hello pubsub');
//        });
//      });
//    });
//
//    describe('Container', function () {
//      var container = require('../container');
//      it('Should be ok', function () {
//        var c = container.Bag(3);
//        // single
//        c.add(new itemLib.Item(1), 1)[0].should.have.property('slot').equal(0);
//        c.get(0).should.have.property('count').equal(1);
//        c.add(new itemLib.Item(1), 99)[0].should.have.property('slot').equal(0);
//        c.get(0).should.have.property('count').equal(99);
//        c.get(1).should.have.property('count').equal(1);
//        c.add(new itemLib.Item(1), 999)[0].should.have.property('left').equal(802);
//        c.add(new itemLib.Item(1), 999)[0].should.have.property('left').equal(999);
//        c.get(1).should.have.property('count').equal(99);
//        c.get(2).should.have.property('count').equal(99);
//        c.add(new itemLib.Item(1), 99)[0].should.have.property('left').equal(99);
//        c.removeItemAt(0)[0].should.have.property('slot').equal(0);
//        c.removeById(1, 1)[0].should.have.property('slot').equal(1);
//        c.removeById(1, 100)[0].should.have.property('slot').equal(1);
//        should(c.get(0)).equal(null);
//        should(c.get(1)).equal(null);
//        should(c.get(2)).have.property('count').equal(97);
//        c.removeById(1, 100, true).should.equal(false);
//        c.removeItemAt(2);
//        should(c.get(2)).equal(null);
//        // multiple
//        c.add([
//                {item: new itemLib.Item(1), count: 10},
//                {item: new itemLib.Item(1), count: 10},
//                {item: new itemLib.Item(1), count: 10}
//              ]);
//        should(c.add([
//              {item: new itemLib.Item(1), count: 100},
//              {item: new itemLib.Item(1), count: 100},
//              {item: new itemLib.Item(1), count: 100}
//            ],
//            0, true)).equal(false);
//        should(c.get(0)).have.property('count').equal(30);
//        should(c.get(1)).equal(null);
//        should(c.get(2)).equal(null);
//        c.remove([{item: 1, count: 1}, {item: 1, count: 1}]);
//        should(c.remove([{item: 1, count: 20}, {item: 1, count: 20}], null, null, true)).equal(false);
//        should(c.get(0)).have.property('count').equal(28);
//        should(c.get(1)).equal(null);
//        should(c.get(2)).equal(null);
//        c.add(new itemLib.Item(540), 26)[0].should.have.property('slot').equal(1);
//        should(c.add([
//              {item: new itemLib.Item(1), count: 100},
//              {item: new itemLib.Item(1), count: 100},
//              {item: new itemLib.Item(1), count: 100}
//            ],
//            0, true)).equal(false);
//        should(c.add([
//              {item: new itemLib.Item(1), count: 101},
//              {item: new itemLib.Item(1), count: 102},
//              {item: new itemLib.Item(1), count: 103}
//            ], 0)[0]).have.property('slot').equal(0);
//        should(c.add(new itemLib.Item(1), 1, true)).equal(false);
//        should(c.get(0)).have.property('count').equal(99);
//        should(c.get(1)).have.property('count').equal(25);
//        should(c.get(2)).have.property('count').equal(1);
//        should(c.get(3)).have.property('count').equal(99);
//        should(c.get(4)).have.property('count').equal(99);
//        c.add(new itemLib.Item(540), 26)[0].should.have.property('slot').equal(2);
//      });
//    });
//    describe('CommandStreamTest', function () {
//      it('Test basics', function () {
//        var p = new playerLib.Player({name:'Player'});
//        p.isNewPlayer = true;
//        p.initialize();
//
//        x = p;
//        z = serialLib.objectlize(p.dump());
//        //for (var k in x) {
//        //  if (!z[k] || !x[k]) console.log(k, z[k], x[k]);
//        //  should(z[k]).eql(x[k]);
//        //}
//        //for (var k in z) {
//        //  if (!z[k] || !x[k]) console.log(k, z[k], x[k]);
//        //  should(z[k]).eql(x[k]);
//        //}
//        should(x).eql(z);
//      });
//    });
//
//    describe('#Hero', function () {
//      it('Should complete without errors', function () {
//        dbLib.loadPlayer(playerName, function (err, player) {
//          //TODO
//          //player.stage.should.length(1);
//          player.completeStage(0);
//          player.stage[0].should.have.property('state').equal(STAGE_STATE_PASSED);
//          player.completeStage(1);
//          player.stage[1].should.have.property('state').equal(STAGE_STATE_PASSED);
//          player.completeStage(7);
//          player.stage[7].should.have.property('state').equal(STAGE_STATE_PASSED);
//          player.completeStage(78);
//          player.isNewPlayer.should.not.equal(true);
//          var config = {
//            name: playerName, class : 0, gender: 1, hairStyle : 2, hairColor : 3
//          };
//          player.createHero(config);
//          config.class = 1;
//          player.addHeroExp(100000);
//          player.createHero().level.should.equal(10);
//          player.createHero(config);
//          config.class = 2;
//          player.createHero(config);
//          player.save();
//          assert.equal(null, player.createHero({class:0}));
//          player.addHeroExp(NaN);
//          player.addHeroExp(0);
//          player.addHeroExp(10000);
//          assert.ok(player.createHero().level > 0);
//        });
//      });
//
//      it('Campaign test', function (done) {
//        dbLib.loadPlayer(playerName, function (err, player) {
//          player.onLogin()[0].should.have.property('day').equal(0);
//          player.claimLoginReward();
//          player.onLogin()[0].claim.should.equal(false);
//          player.loginStreak.date -= 24*60*60*1000;
//          player.onLogin()[0].should.have.property('day').equal(1);
//          player.claimLoginReward();
//          player.loginStreak.date -= 24*60*60*1000;
//          player.onLogin()[0].should.have.property('day').equal(2);
//          player.claimLoginReward();
//          player.loginStreak.date -= 24*60*60*1000;
//          player.onLogin()[0].should.have.property('day').equal(3);
//          player.claimLoginReward();
//          player.loginStreak.date -= 24*60*60*1000;
//          player.onLogin()[0].should.have.property('day').equal(4);
//          player.claimLoginReward();
//          player.loginStreak.date -= 24*60*60*1000;
//          player.onLogin()[0].should.have.property('day').equal(0);
//          player.loginStreak.date -= 2*24*60*60*1000;
//          player.onLogin()[0].should.have.property('day').equal(0);
//          done();
//        });
//      });
//
//      it('Could you be my friend', function (done) {
//        var arr = [];
//        for (var i = 0; i < countOfOthers; i++) arr.push(i);
//        dbLib.loadPlayer(playerName, function (err, player) {
//          async.map(arr,
//            function (id, cb) { player.inviteFriend(othersName+id, null, cb); },
//            function (err, results) {
//              async.map(arr,
//                function (id, cb) {
//                  dbLib.loadPlayer(othersName+id, function (err, p) {
//                    p.fetchMessage(function (err, msg) {
//                      msg.should.length(1);
//                      msg[0].should.have.property('NTF').equal(Event_FriendApplication);
//                      msg[0].should.have.property('arg').have.property('act');
//                      p.operateMessage(null, msg[0].arg.sid, NTFOP_ACCEPT, cb);
//                    });
//                  });
//                }, function () { done(); });
//            });
//        });
//      });
//    });
//
//    describe('Commands', function () {
//      var requestHandlers = require('../requestHandlers').route;
//      var router = require('../router');
//      //router.route([], { CNF: 103, arg: { sign: '0' }, CMD: 103 }, {}, console.log)
//      it('RPC_Login & RPC_Register', function (done) {
//        var requestInfo = {
//            tp: LOGIN_ACCOUNT_TYPE_AD,
//            id: '1', 
//            rv: queryTable(TABLE_VERSION, 'resource_version'), 
//            bv: queryTable(TABLE_VERSION, 'bin_version'), 
//            ch: 'ai' 
//          };
//        requestHandlers['RPC_Login'].func(
//          requestInfo, 
//          null,
//          function (res) {
//            if (res && res[0].RET == RET_AccountHaveNoHero) {
//              requestHandlers['RPC_Register'].func({
//                nam: playerName+'c',
//                cid: rand()%3,
//                gen: rand()%2,
//                hst: rand()%3,
//                hcl: rand()%18,
//                pid: res[0].arg.pid.toString()
//                },
//                null,
//                function (err, res) {
//                  done();
//                },
//                1,
//                {pendingLogin: requestInfo}
//                );
//            } else {
//              //print(res);
//              done();
//            }
//          });
//      });
//      it('RPC_GameStartDungeon', function (done) {
//        dbLib.loadPlayer(playerName, function (err, me) {
//          //me.startDungeon(0, true, console.log);
//          requestHandlers.RPC_GameStartDungeon.func(
//            { stg : 0 }, 
//            me,
//            function (res) {
//              done();
//            },
//            9527);
//        });
//      });
//      it('RPC_RoleInfo', function (done) {
//        handlers[RPC_RoleInfo].func(
//          {nam: playerName},
//          null,
//          function (hero) {
//            var err = null;
//            if (hero) {
//              err = null;
//            } else {
//              err = new Error('No hero');
//            }
//
//            done(err);
//          },
//          9527);
//      });
//      require('../shared');
//      it('RPC_BuyFeature', function (done) {
//        dbLib.loadPlayer(playerName, function (err, me) {
//          if (err) done(err);
//          handlers[RPC_BuyFeature].func({typ: FEATURE_ENERGY_RECOVER}, me, function (ret) {
//            if (ret[0].RET !== RET_NotEnoughDiamond) { done(new Error('Should be  RET_NotEnoughDiamond')); }
//          }, 9527);
//          me.diamond += 65;
//          me.energy -= 15;
//          handlers[RPC_BuyFeature].func({typ: FEATURE_ENERGY_RECOVER, tar: 150}, me, function (ret) {
//            if (ret[0].RET !== RET_OK) { done(new Error('Should be OK')); }
//            if (ret[1].arg.eng !== 150) { done(new Error('Energe wrong')); }
//            if (ret[2].arg.dim !== 0) { done(new Error('Diamond cost wrong')); }
//          }, 9527);
//          //handlers[RPC_BuyFeature].func({typ: FEATURE_INVENTORY_STROAGE}, me, function (ret) {
//          //  console.log(ret, me.diamond);
//          //  if (ret[0].RET !== RET_OK) { done(new Error('Should be OK')); }
//          //  if (ret[2].arg.eng !== 150) { done(new Error('Diamond cost wrong')); }
//          //  if (ret[2].arg.dim !== 0) { done(new Error('Diamond cost wrong')); }
//          //}, 9527);
//        });
//        done();
//      });
//    });
//
    describe('Lock & Unlock', function (done) {
      it('Should unlock stage & quest with no prev', function () {
        var initialQuest = updateQuestStatus([]).length;
        shall(initialQuest > 0).equal(true);
        //updateQuestStatus([])[0].should.equal(6);
        //should(updateQuestStatus([{complete:true}]).length > (initialQuest - 1)).equal(true);
        //updateStageStatus([]).should.length(1);
        //updateStageStatus([])[0].should.equal(0);
        //updateStageStatus([{}]).should.length(0);
        //updateStageStatus([{state:STAGE_STATE_PASSED}]).should.length(1);
        var x = [];
        x[104] = {state: STAGE_STATE_PASSED};
        //console.log(updateStageStatus(x, {stage: x}));
      });
    });
//
//    describe('Item operation', function () {
//      it('aquireItem', function (done) {
//        dbLib.loadPlayer(playerName, function (err, me) {
//          me.claimPrize([
//                  {type: PRIZETYPE_EXP, count: 123456},
//                  {type: PRIZETYPE_ITEM, value: 0, count: 100},
//                  {type: PRIZETYPE_ITEM, value: 0, count: 100000}
//                ]
//            ).should.equal(false);
//          //me.aquireItem(36);
//          //me.aquireItem(40);
//          done(err);
//        });
//      });
//
//      it('craftItem', function () {
//        dbLib.loadPlayer(playerName, function (err, me) {
//          //var ret1 = me.aquireItem(558, 99);
//          //var ret2 = me.aquireItem(564, 1);
//          //me.gold = 5000;
//          //print('1', ret1);
//          //print('2', ret2);
//          //var ret = me.craftItem(1);
//          //print('3', ret);
//        });
//      });
//
//      it('transformGem', function () {
//        dbLib.loadPlayer(playerName, function (err, me) {
//          //me.aquireItem(0, 99);
//          //var ret = me.transformGem(10);
//          //console.log(ret);
//        });
//      });
//
//      it('levelUpItem', function () {
//        dbLib.loadPlayer(playerName, function (err, me) {
//          me.aquireItem(32);
//          me.levelUpItem(1).ret.should.equal(RET_ItemNotExist);
//          me.levelUpItem(0).ret.should.equal(RET_EquipCantUpgrade);
//          me.hero.xp+=1000;
//          me.levelUpItem(0).ret.should.equal(RET_InsufficientEquipXp);
//          me.getItemAt(0).xp += 1000;
//          me.levelUpItem(0).ret.should.equal(RET_NotEnoughGold);
//          me.gold+=1000;
//          me.getItemAt(0).rank.should.equal(1);
//          me.levelUpItem(0);
//          me.getItemAt(0).rank.should.equal(2);
//          //var nextLevel = me.inventory.get(1).upgradeTarget;
//          //assert.equal(nextLevel, me.inventory.get(1).id);
//        });
//      });
//
//      it('Enhance', function (done) {
//        dbLib.loadPlayer(playerName, function (err, me) {
//          //print(me.syncCampaign());
//          me.gold = 5000;
//          me.useItem(0);
//          me.sellItem(0);
//          me.sellItem(1);
//          me.sellItem(2);
//          me.sellItem(3);
//          me.aquireItem(32);
//          me.aquireItem(0, 99);
//          me.getItemAt(0).should.have.property('id').equal(32);
//          me.getItemAt(1).should.have.property('id').equal(0);
//          me.enhanceItem(1, 0).ret.should.equal(RET_EquipCantUpgrade);
//          me.enhanceItem(0, 0).ret.should.equal(RET_NoEnhanceStone);
//          me.enhanceItem(0, 1);
//          me.getItemAt(0).should.have.property('enhancement').length(1);
//          me.getItemAt(1).should.have.property('count').equal(98);
//          me.enhanceItem(0, 1);
//          me.getItemAt(1).should.have.property('count').equal(96);
//          me.enhanceItem(0, 1);
//          me.getItemAt(1).should.have.property('count').equal(94);
//          me.enhanceItem(0, 1);
//          me.getItemAt(1).should.have.property('count').equal(92);
//          done();
//        });
//      });
//
//      //it('Recycle', function (done) {
//      //  dbLib.loadPlayer(playerName, function (err, me) {
//      //    //me.aquireItem
//      //    done(err);
//      //  });
//      //});
//    });
//  });
});
