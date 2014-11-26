require('should');
var createItem = require('../js/item').createItem;
var Unit = require('../js/unit').Unit;

describe('Item', function () {
  describe('Equipment', function () {
      var Enhance_Stone = require('../js/item').Enhance_Stone;
      var CreateSword = function () {
          return createItem({
              category: 1,
              basic_properties: {
                  attack: 20,
                  strength: 10
              },
              effectf: {id: 1},
              effectm: {id: 2}
          });
      };
      var gem_pariticle = {
          command: [
              { type: 'change_appearance', appearance: {particle: 4} } ,
          ]
      };
      var gemConfig = {
          expiration: {},
          command: [
              { type: 'incress_property', property: { attack: 10 } },
              { type: 'install_skill', id: 1, level: 1 } ,
          ]
      };

      it('不同性别穿上会有不同外观', function () {
          var sword = CreateSword();
          sword.executeCommand('update_appearance', {gender: 1});
          sword.appearance().should.eql({id:2});
      });

      it('可能因为强化而改变外观', function () {
          var sword = CreateSword();
          var gem = new Enhance_Stone(gem_pariticle);
          sword.executeCommand('update_appearance', {gender: 0});
          sword.installEnhancement(gem);
          sword.appearance().should.eql({id:1, particle: 4});
      });

      it('强化:属性', function () {
          var sword = CreateSword();
          var gem = new Enhance_Stone(gemConfig);
          sword.installEnhancement(gem);
          sword.property().should.eql({attack: 30, strength: 10});
      });

      it('强化:技能', function () {
          var sword = CreateSword();
          var gem = new Enhance_Stone(gemConfig);
          sword.installEnhancement(gem);
          sword.skill.should.eql([{id:1, level:1}]);
      });

      it('套装', function () {
          var suitConfig = {
              'suitId':1,
              '2': [ { type: 'incress_property', property: { attack: 10 } } ],
              '4': [ { type: 'incress_property', property: { attack: 10 } },
                     { type: 'change_appearance', appearance: { head: 10 } }]
          };
          var unit = new Unit();
          unit.equip(createItem({suit_config: suitConfig, subcategory: 0, basic_properties: { attack : 1 }}));
          unit.attack.should.equal(1);

          unit.equip(createItem({suit_config: suitConfig, subcategory: 1, appearance: { head : 1 }}));
          unit.attack.should.equal(11);
          unit.appearance.should.eql({ head: 1});

          unit.equip(createItem({suit_config: suitConfig, subcategory: 2, appearance: { body : 1 }}));
          unit.attack.should.equal(11);
          unit.appearance.should.eql({ body: 1, head: 1});

          unit.equip(createItem({suit_config: suitConfig, subcategory: 3}));
          unit.attack.should.equal(21);
          unit.appearance.should.eql({ body: 1, head: 10});
      });

      //it('强化:时间限制', function () {
      //    var sword = CreateSword();
      //    var gem = new Enhance_Stone(gemConfig);
      //    sword.installEnhancement(gem);
      //    throw 'TODO'
      //});
  });
});
