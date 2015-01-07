shall = require('should');
require('../js/define');
var playerLib = require('../js/player');
//var assert = require("assert");
//var serialLib = require('../serializer');
//var dungeonLib = require('../js/dungeon');
//var should = require('should');
//var spellLib = require('../js/spell');
var helpLib = require('../js/helper');
var dbLib = require('../js/db');


dbPrefix = 'Develop'+'.';
dbLib.initializeDB({
  "Account": { "IP": "10.4.3.41", "PORT": 6379},
  "Role": { "IP": "10.4.3.41", "PORT": 6379},
  "Publisher": { "IP": "10.4.3.41", "PORT": 6379},
  "Subscriber": { "IP": "10.4.3.41", "PORT": 6379}
  // "Account": { "IP": "localhost", "PORT": 6379},
  // "Role": { "IP": "localhost", "PORT": 6379},
  // "Publisher": { "IP": "localhost", "PORT": 6379},
  // "Subscriber": { "IP": "localhost", "PORT": 6379}
});

/*
describe('Unit', function () {
  it('levelUp', function () {
    initGlobalConfig('../../build/', function() {
      var data =[
      {exp: 0, lvl: 1, skill:{'0':1,'76':1}},
      {exp: 110, lvl: 2, skill:{'0':1,'76':1}},
      {exp: 300, lvl: 3, skill:{'0':1,'2':1,'76':1}},
      {exp: 1600, lvl: 9, skill:{'0':2,'2':1, '76':1}},
      {exp: 1603, lvl: 9, skill:{'0':2,'2':1, '76':1}},
//      {exp: 300, lvl: 4, skill:{'2':1}},
//      {exp: 300, lvl: 4, skill:{'2':1}},
//      {exp: 300, lvl: 4, skill:{'2':1}},
      ]

      helpLib.initLeaderboard(queryTable(TABLE_LEADBOARD));

      dbLib.tryAddLeaderboardMember = function(q,b,c,d) {}
      var p = new playerLib.Player();
      p.setName('Test');
      p.notify = function (a,b) {}
      p.hero = p.createHero({name: 'K', class: 0, gender: 1, hairStyle: 1, hairColor: 1});

      data.forEach(function (e) {
        p.hero.xp = e.exp;
        p.hero.initialize();
        p.hero.levelUp();

        p.hero.level.should.equal(e.lvl);
        sdb = p.hero.wSpellDB
        for (var k in e.skill) {
          sdb[k].level.should.eql(e.skill[k]);
        }
      });
    });
  });
});

*/
