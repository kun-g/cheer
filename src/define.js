require('./shared');
var triggerLib = require('./trigger');

DUNGEON_RESULT_DONE = 2;
DUNGEON_RESULT_WIN = 1;
DUNGEON_RESULT_FAIL = 0;

HEROTAG = 100;
InitialBagSize = 30;
MERCENARYLISTLEN = 2;
RECRUIT_COST = -5;

STAGE_STATE_INACTIVE = 0;
STAGE_STATE_ACTIVE = 1;
STAGE_STATE_PASSED = 2;

ENERGY_MAX = 100;
ENERGY_RATE = 360000; // 1min
TEAMMATE_REWARD_RATIO = 0.2;
//////////////////// Log
serverType = 'None';
print = console.log;
dprint = function(obj) { console.log(require('util').inspect(obj, true, 10));}
logger = null;
initServer = function () {
  var pid = process.pid;
  async = require('async');
  print = function (type, log) {
    if (log == null) {
      log = type;
      type = null;
    }
    if (typeof log !== 'object') {
      log = {log:log}; 
    }
    log.time = (new Date()).valueOf();
    log.pid = pid;
    log.server = gServerID;
    log.logType = type;

    if (logger && type) {
      logger.emit(type, log, new Date());
    }
    if (logger == null || process.stdout.isTTY || type === 'Error') {
      var util = require('util');
      var config = {depth : 11};
      //if (process.stdout.isTTY) config.colors = true;
      console.log(util.inspect(log, config));
    }
  };
};

logError = function(log) { print('Error', log); };
logInfo = function(log) { print('Info', log); };
logUser = function(log) { print('User', log); };
logWarn = function(log) { print('Warn', log); };

rand = function() {
  return Math.floor(Math.random()*1000000);
};

isNameValid = function(name) {
  var ban = ['\\.', ' ', '\\?', '@', '!', '#', '\\$', '%', '\\^', '\\\\', '\\\*',
      '\\]', '\\[', ',',
      ];
  for (var x in ban) {
    var reg = new RegExp(ban[x],'g');
    var matches = reg.exec(name);
    if (matches) {
      return false;
    }
  }
  return true;
};

grabAndTranslate = function (data, translateTable) {
  if (data == null || translateTable == null) return {};
  var ret = {};
  var flag = false;

  for (var k in translateTable) {
    if (data[k] != null) {
      ret[translateTable[k]] = data[k];
      flag = true;
    }
  }

  if (!flag) return null;
  return ret;
};

listAllProperties = function(o){     
  var objectToInspect;     
  var result = [];

  for(objectToInspect = o; objectToInspect !== null; objectToInspect = Object.getPrototypeOf(objectToInspect)){  
    result = result.concat(Object.getOwnPropertyNames(objectToInspect));  
  }

  return result; 
};

createMirrorHero = function (data) {
  cfg = queryTable(TABLE_ROLE, data.class);
  //TODO:
  hero = {
    xp: data.xp,
    name: data.name,
    class: cfg.transId,
    gender: data.gender,
    hairStyle: data.hairStyle,
    hairColor: data.hairColor,
    equipment: data.equipment
  };
  hero = new Hero(hero);
  battleForce = hero.calculatePower();
  hero.health = battleForce * (10/18.5);
  hero.attack = battleForce * (0.3/18.5);
  hero.critical = battleForce * (1/18.5);
  hero.strong = battleForce * (1/18.5);
  hero.accuracy = battleForce * (1/18.5) + 20;
  hero.reactivity = battleForce * (10/18.5) - 20;
  hero.speed = battleForce * (1/18.5) + 20;
  return hero;
};

getBasicInfo = function (hero) {
  if (!hero) throw 'Invalid Hero Data';
  var translateTable = {
    name : 'nam',
    gender : 'gen',
    class : 'cid',
    hairStyle : 'hst',
    hairColor : 'hcl',
    xp : 'exp',
    isFriend: 'ifn',
    vipLevel: 'vip'
  };

  var ret = grabAndTranslate(hero, translateTable);

  if (hero.equipment) {
    var item = [];
    for (var k in hero.equipment) {
      var e = hero.equipment[k];
      if (e.eh) {
        item.push({cid:e.cid, eh:e.eh});
      } else {
        item.push({cid:e.cid});
      }
    }
    if (item.length > 0) ret.itm = item;
  }

  return ret;
};

initStageConfig = function (cfg) {
  var ret = [];
  cfg.forEach(function (c) {
    if (c.abtest) {
      c.abtest.forEach( function (chapter) {
        chapter.stage.forEach(function (s, index) {
          if (!ret[s.stageId]) {ret[s.stageId] = {abtest : []};}
          s.chapter = chapter.chapterId;
          ret[s.stageId].abtest.push(s);
        });
      });
    } else {
      c.stage.forEach(function (s, index) {
        ret[s.stageId] = s; 
        ret[s.stageId].chapter = c.chapterId;
      });
    }
  });
  ret.forEach(function (c) {
    // TODO: abtest
    if (c.abtest) c = c.abtest[0];
    if (c.prev) {
      c.prev.forEach(function (p) {
        if (ret[p]) {
          if (ret[p].abtest) {
            for (var k in ret[p].abtest) {
              if (!ret[p].abtest[k].next) ret[p].abtest[k].next = [];
              ret[p].abtest[k].next.push(c.stageId);
            }
          } else {
            if (!ret[p].next) ret[p].next = [];
            ret[p].next.push(c.stageId);
          }
        }
      });
    } else {
      c.prev = [];
    }
  });
  return ret;
};

prepareForABtest = function (cfg) {
  var ret = [];
  var maxABIndex = 0;
  if (!Array.isArray(cfg)) return [cfg];
  cfg.forEach(function (c, index) {
    if (c.abtest && c.abtest.length > maxABIndex) maxABIndex = c.abtest.length;
    ret[index] = c;
  });
  if (maxABIndex > 0) {
    ret = [];
    for (var i = 0; i < maxABIndex; i++) {
      ret.push(cfg.map( function (e) {
        if (e.abtest) {
          return e.abtest[i % e.abtest.length];
        } else {
          return e;
        }
      }));
    }
  } else {
    ret = [ret];
  }
  return ret;
};

varifyDungeonConfig = function (cfg) {
  return cfg;
};

function initShop (data) {
  if (typeof gShop != 'undefined') {
    for (var k in data) {
      gShop.addProduct(k, data[k]);
    }
  }
}

arenaPirze = function (rank) {
  cfg = queryTable(TABLE_ARENA);
  for (var k in cfg) {
    var v = cfg[k];
    if (rank <= v.top) {
      return v.prize;
    }
  }
  return []
}
var gConfigTable = {};
initGlobalConfig = function (path, callback) {
  queryTable = function (type, index, abIndex) {
    var cfg = gConfigTable[type];
    if (!cfg) return null;
    if (abIndex != null) {
      cfg = cfg[abIndex % cfg.length];
    } else {
      cfg = cfg[0];
    }

    if (index == null) {
      return cfg;
    } else {
      if (cfg[index]) {
        switch (type) {
          case TABLE_ITEM:
          case TABLE_ROLE: 
            return JSON.parse(JSON.stringify(cfg[index])); //TODO: hotfix
            break;
          default:
            return cfg[index]
        }
      } else {
        return null;
      }
    }
  };
  var configTable = [{name:TABLE_LEADBOARD}, {name: TABLE_STORE, func:initShop},
    {name:TABLE_ROLE}, {name:TABLE_LEVEL}, {name:TABLE_VERSION}, {name:TABLE_FACTION},
    {name:TABLE_ITEM}, {name:TABLE_CARD}, {name:TABLE_DUNGEON, func:varifyDungeonConfig},
    {name:TABLE_STAGE, func: initStageConfig}, {name:TABLE_QUEST}, {name: TABLE_COSTS},
    {name:TABLE_UPGRADE}, {name:TABLE_ENHANCE}, {name: TABLE_CONFIG}, {name: TABLE_VIP},
    {name:TABLE_SKILL}, {name:TABLE_CAMPAIGN}, {name: TABLE_DROP}, {name: TABLE_TRIGGER},
    {name:TABLE_DP},{name:TABLE_ARENA}
  ];
  if (!path) path = "./";
  configTable.forEach(function (e) {
    gConfigTable[e.name] = require(path+e.name).data;
    if (!gConfigTable[e.name]) throw Error("Table not found"+e.name);
    if (e.func) gConfigTable[e.name] = e.func(gConfigTable[e.name]);
    gConfigTable[e.name] = prepareForABtest(gConfigTable[e.name]);
  });
  callback();
};

showMeTheStack = function () {try {a = b;} catch (err) {console.log(err.stack);}};

//////////// exit routine
onDBShutDown = function () { };
onAllDataSaved = function () {
  require('./db').releaseDB();
};
onNetworkShutDown = function () {
  if (dbClient && savingAllPlayer != null) {
    savingAllPlayer(onAllDataSaved);
  } else {
    onAllDataSaved();
  }
};

exports.initStageConfig = initStageConfig;

QUEST_TYPE_NPC = 0;
QUEST_TYPE_ITEM = 1;
QUEST_TYPE_GOLD = 2;
QUEST_TYPE_DIAMOND = 3;
QUEST_TYPE_LEVEL = 4;
QUEST_TYPE_POWER = 5;
////////////////////
wrapCallback = function() {
  var callback, me, errCallback;
  for (var i in arguments) {
    e = arguments[i];
    switch (typeof e) {
      case 'object' : 
        me = e; break;
      case 'function' :
        if (callback) {
          errCallback = e;
        } else {
          callback = e;
        }
    }
  }
  if (errCallback) errCallback = wrapCallback(me, errCallback);
  return function () {
    try {
      if (callback) {
        return callback.apply(me, arguments);
      }
    } catch (err) {
      var errMsg = { error : err };

      if (err.stack) errMsg.stack = err.stack;

      var caller = arguments.callee.caller;
      if (caller && caller.name) errMsg.caller = caller.name;

      logError(errMsg);

      if (errCallback) {
        return errCallback.apply(me, [err].concat(arguments));
      }
    }
  };
};

deepCopy = function (obj) {
  if (typeof obj === 'object') {
    var ret = {};
    if (Array.isArray(obj)) ret = [];
    for (k in obj) {
      v = obj[k];
      ret[k] = deepCopy(v);
    }
    return ret;
  } else {
    return obj;
  }
};

packQuestEvent = function (quests, id, version) {
  var ret = { NTF: Event_UpdateQuest };
  var qst = [];
  for (var k in quests) {
    if (id != null && k != id) continue;
    if (quests[k] && quests[k].counters) {
      qst.push({qid: k, cnt: quests[k].counters});
    }
  }
  ret.arg = {qst: qst};
  if (version != null) ret.arg.syn = version;
  return ret;
};

selectElementFromWeightArray = function (array, randNumber) {
  if (!array) {
    logError({action: 'selectElementFromWeightArray', reason: 'emptyArray'});
    return null;
  }
  var total = array.reduce(function (r, l) {return r+l.weight;}, 0);
  if (randNumber < 1) randNumber *= total;
  randNumber = Math.ceil(Math.abs(randNumber%total));
  for (var k in array) {
    if (randNumber <= array[k].weight) {
      if (!array[k]) {
        logError({action: 'selectElementFromWeightArray', reason: 'emptyArray1'});
      }
      return array[k];
    }
    randNumber -= array[k].weight;
  }
  logError({action: 'selectElementFromWeightArray', reason: 'emptyArray2'});
  return null;
};

mapContact = function (target, source) {
  if (typeof target != 'object' || typeof source != 'object') {
    logError({action: 'mapContact', reason: 'invalidate parm'});
    return null;
  }
  for(var k in source) {
    target[k] = source[k];
  }
  return target
}

logLevel = 0;

updateStageStatus = function (stageStatus, player, abindex) {
  if (!stageStatus) return [];
  var stageConfig = queryTable(TABLE_STAGE);
  var ret = [];
  for (var sid = 0; sid < stageConfig.length; sid++) {
    var stage = queryTable(TABLE_STAGE, sid, abindex);
    var unlockable = true;
    if (stage.cond) unlockable = triggerLib.conditionCheck(stage.cond, player);
    if (unlockable && stageStatus[sid] == null) ret.push(sid);
    if (stage.isInfinite 
        && stageStatus[sid] 
        && stageStatus[sid].level == null)
      ret.push(sid);
  }
  return ret;
};

updateQuestStatus = function (questStatus, player, abindex) {
  if (!questStatus) return [];
  var questConfig = queryTable(TABLE_QUEST);
  var ret = [];
  questConfig.forEach(function (quest, qid) {
    var unlockable = true;
    if (quest.cond) unlockable = triggerLib.conditionCheck(quest.cond, player);
    if (unlockable && (typeof questStatus[qid] == 'undefined' || questStatus[qid] === null)) ret.push(qid);
  });
  return ret;
};

shuffle = function (array, mask) {
  var indexes = [];
  for (var i = 0; i < array.length; i++) indexes.push(i);
  var permutations = 1;
  for (var p = 2; p <= array.length; p++) permutations *= p;
  if (mask < 1) mask = Math.floor(mask*permutations);
  mask = mask % permutations;
  var result = [];
  for (var j = 0; j < array.length; j++) {
    var nextPermutations = permutations/(array.length-j);
    var currentSelector = Math.floor(mask/nextPermutations);
    result[j] = array[indexes.splice(currentSelector%(array.length-j), 1)];
    mask %= nextPermutations;
    permutations = nextPermutations;
  }
  return result;
};

/////////////////////////// For client
ENHANCE_LIMIT = 4;
ENHANCE_MAXLEVEL = 10;

DUNGEON_ACTION_ENTER_DUNGEON = 0;
DUNGEON_ACTION_EXPLOREBLOCK = 1;
DUNGEON_ACTION_CANCEL_DUNGEON = 2;
DUNGEON_ACTION_USE_ITEM_SPELL = 3;
DUNGEON_ACTION_CAST_SPELL = 4;
DUNGEON_ACTION_ATTACK = 5;
DUNGEON_ACTION_ACTIVATEMECHANISM = 6;
DUNGEON_ACTION_REVIVE = 7;
DUNGEON_ACTION_TOUCHBLOCK = 8;

DUNGEON_DROP_CARD_SPELL = 49;

ACT_MOVE = 0;
ACT_ATTACK = 1;
ACT_HURT = 2;
ACT_DEAD = 3;
ACT_MOVE2 = 4;
ACT_SPELL = 5;
ACT_EVADE = 6;
ACT_SHIFTORDER = 7;
ACT_TELEPORT = 8;
ACT_WhiteScreen = 9;
ACT_Delay = 10;
ACT_Dialog = 11;

ACT_POPHP = 101;
ACT_POPTEXT = 102;
ACT_DROPITEM = 103;
ACT_EFFECT = 104;
ACT_SkillCD = 105;
ACT_EventDummy = 106;
ACT_PlaySound = 108;
ACT_ChangeBGM = 109;
ACT_Shock = 110;
ACT_Blink = 111;
ACT_Tutorial = 112;

ACT_Block = 201;
ACT_Enemy = 202;
ACT_UnitInfo = 203;
ACT_DungeonResult = 204;
ACT_EnterLevel = 205;
ACT_AllHeroAreDead = 206;
ACT_ReplayMissMatch = 207;

ACT_Event = 300;

HP_RESULT_TYPE_MISS = 0;
HP_RESULT_TYPE_HIT = 1;
HP_RESULT_TYPE_CRITICAL = 2;
HP_RESULT_TYPE_BLOCK = 3;
HP_RESULT_TYPE_HEAL = 4;

BUFF_TYPE_NONE = 0;
BUFF_TYPE_DEBUFF = 1;
BUFF_TYPE_BUFF = 2;

Block_Empty = 0;
Block_Exit = 1; 
Block_Enemy = 2;
Block_Npc = 3;
Block_LockedExit = 4;
Block_TreasureBox = 5;
Block_Hero = 10;

Unit_Hero = 0;
Unit_Enemy = 1;
Unit_NPC = 2;
Unit_TreasureBox = 3;
Unit_Mirror = 4;
Unit_Boss = 5;
Unit_Exit = 100;

Dungeon_Width = 5;
Dungeon_Height = 6;
DG_LEVELWIDTH = 5;
DG_LEVELHEIGHT = 6;
DG_BLOCKCOUNT = DG_LEVELHEIGHT*DG_LEVELWIDTH;
UP = 0;
RIGHT = 1;
DOWN  = 2;
LEFT  = 3;

isInstantAction = function (act) { return act > 100; };

RPC_GameStartDungeon = 1;
Request_DungeonExplore = 2;
Request_DungeonActivate = 3;
Request_DungeonAttack = 4;
Request_DungeonSpell = 5;
Request_DungeonCard = 6;
Request_DungeonUseItem = 7;
Request_DungeonRevive = 8;
Request_DungeonTouch = 9;
REQUEST_CancelDungeon = 20;

Event_DungeonEnter = 0;
Event_SyncVersions = 1;
Event_RoleUpdate = 2;
Event_DungeonAction = 3;
Event_NewFriend = 4;
Event_InventoryUpdateItem = 5;
Event_Dummy = 6;
Event_ForgeUpdate = 7;
Event_UpdateStoreInfo = 10;
Event_Fail = 11;
Event_UpdateQuest = 19;

exports.fileVersion = -1;
