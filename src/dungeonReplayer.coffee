#require('strong-agent').profile()
util = require 'util'
require './define'
dbLib = require './db'
{Dungeon} = require './dungeon'

initServer()

loadDungeon = (name, id, callback) ->
  GLOBAL['dbPrefix'] = 'Develop.'
  dbLib.initializeDB({
    "Account": { "IP": "localhost", "PORT": 6379},
    "Role": { "IP": "localhost", "PORT": 6379},
    "Publisher": { "IP": "localhost", "PORT": 6379},
    "Subscriber": { "IP": "localhost", "PORT": 6379}
  })
  setTimeout () =>
    dbLib.loadDungeon name, id, (err, dungeon) =>
      dbLib.releaseDB()
      callback err, dungeon if callback
  ,100


initGlobalConfig(() ->
  rep = [ [ { a: 0, r: 455529896 },
             { a: 1, g: { b: 11, p: [ 10, null, null ] }, r: 748376054 },
             { a: 1, g: { b: 16, p: [ 11, null, null ] }, r: 415642431 },
             { a: 5, g: { t: 16, p: [ 11, null, null ] }, r: 863033710 },
             { a: 1, g: { b: 21, p: [ 16, null, null ] }, r: 430727470 },
             { a: 1, g: { b: 22, p: [ 21, null, null ] }, r: 736149779 },
             { a: 5, g: { t: 22, p: [ 21, null, null ] }, r: 700116866 },
             { a: 1, g: { b: 23, p: [ 22, null, null ] }, r: 676176050 },
             { a: 6, g: { t: 23 }, r: 812400584 },
             { a: 1, g: { b: 18, p: [ 23, null, null ] }, r: 439072826 },
             { a: 5, g: { t: 18, p: [ 23, null, null ] }, r: 394165723 },
             { a: 5, g: { t: 18, p: [ 23, null, null ] }, r: 989965198 },
             { a: 6, g: { t: 13 }, r: 250951614 } ] ]
  init = {
    stage: 104,
    initialQuests: { '153': { counters: [ 0 ] } },
    blueStar: 0,
    abIndex: 563534,
    team: [ { nam: '改革刚刚改革', gen: 1, cid: 0, hst: 2, hcl: 2, exp: 0 } ],
    randSeed: 47867
  }
  d = new Dungeon(init)
  d.initialize()
  d.replayActionLog(rep)
  console.log(d.reward)
)
#
#loadDungeon('ffcdd', 0, (err, dungeon) ->
#  start = process.hrtime()
#  count = 1
#  max = 0
#  return console.log('Loading failed') unless dungeon
#  for i in [1..count]
#    s = process.hrtime()
#    d = new Dungeon(dungeon.getInitialData())
#    d.initialize()
#    d.getHeroes().forEach( (h) -> console.log(h.health, h.name) )
#    actionLog = dungeon.actionLog
#    logInfo(dungeon.getInitialData())
#    #d.replayActionLog(actionLog)
#
#    for i, actions of actionLog
#      for k, a of actions
#        console.log(i, k, util.inspect(a, {depth: 10, colors: false}))
#        r = d.act(a.a, a.g, true, true, a.r)
#        d.level.print()
#        console.log(util.inspect(r, {depth: 10, colors: false}))
#    console.log(d.reward)
#    d.getHeroes().forEach( (h) -> console.log(h.health, h.name) )
#    e = process.hrtime(s)
#    if e[0]*1e9 + e[1] > max then max = e[0]*1e9+e[1]
#  end = process.hrtime(start)
#  end = end[0]*1e9+end[1]
#  console.log('Total:', end)
#  console.log('Avarage:', end/count)
#  console.log('Max:', max)
#)
