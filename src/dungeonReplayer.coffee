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
  log = {"action":"verify_dungeon","player":"Bbbv","initial_data":{"stage":1,"initialQuests":{"1":{"counters":[0]}},"blueStar":0,"abIndex":72029,"team":[{"nam":"Bbbv","gen":1,"cid":0,"hst":1,"hcl":4,"exp":0}],"randSeed":16462,"time":1394713426805,"pid":29294,"server":"0","logType":"Info"},"reward":null,"replay":[[{"a":0,"r":302417256},{"a":1,"g":{"b":0,"p":[1,null,null]},"r":423581988},{"a":1,"g":{"b":2,"p":[1,null,null]},"r":41545580},{"a":1,"g":{"b":5,"p":[0,null,null]},"r":694598062},{"a":1,"g":{"b":10,"p":[5,null,null]},"r":583826180},{"a":1,"g":{"b":6,"p":[5,null,null]},"r":754463768},{"a":1,"g":{"b":11,"p":[6,null,null]},"r":889734229},{"a":1,"g":{"b":7,"p":[6,null,null]},"r":499274966},{"a":6,"g":{"t":11},"r":323239797},{"a":1,"g":{"b":12,"p":[7,null,null]},"r":234299774},{"a":1,"g":{"b":8,"p":[7,null,null]},"r":102053810},{"a":5,"g":{"t":8,"p":[7,null,null]},"r":598462721},{"a":1,"g":{"b":3,"p":[8,null,null]},"r":575123389},{"a":1,"g":{"b":9,"p":[8,null,null]},"r":857039939},{"a":1,"g":{"b":4,"p":[9,null,null]},"r":379347529},{"a":1,"g":{"b":14,"p":[9,null,null]},"r":746496221},{"a":1,"g":{"b":13,"p":[14,null,null]},"r":769349396},{"a":1,"g":{"b":17,"p":[12,null,null]},"r":579129808},{"a":1,"g":{"b":16,"p":[11,null,null]},"r":820384332},{"a":1,"g":{"b":21,"p":[16,null,null]},"r":501358335},{"a":1,"g":{"b":22,"p":[21,null,null]},"r":566834298},{"a":1,"g":{"b":18,"p":[17,null,null]},"r":592457448},{"a":5,"g":{"t":18,"p":[17,null,null]},"r":421182301},{"a":1,"g":{"b":19,"p":[18,null,null]},"r":971385906},{"a":1,"g":{"b":23,"p":[18,null,null]},"r":484532379},{"a":1,"g":{"b":24,"p":[19,null,null]},"r":818862279},{"a":5,"g":{"t":24,"p":[19,null,null]},"r":610628426},{"a":5,"g":{"t":24,"p":[19,null,null]},"r":680204480},{"a":1,"g":{"b":29,"p":[24,null,null]},"r":435945195},{"a":1,"g":{"b":28,"p":[29,null,null]},"r":684587385},{"a":6,"g":{"t":28},"r":200905233},{"a":1,"g":{"b":27,"p":[28,null,null]},"r":404522080},{"a":6,"g":{"t":22},"r":186938600}],[{"a":1,"g":{"b":29,"p":[28,null,null]},"r":732749242},{"a":1,"g":{"b":24,"p":[29,null,null]},"r":507611424},{"a":5,"g":{"t":24,"p":[29,null,null]},"r":205244234},{"a":1,"g":{"b":23,"p":[24,null,null]},"r":674439914},{"a":1,"g":{"b":18,"p":[23,null,null]},"r":107094334},{"a":1,"g":{"b":22,"p":[23,null,null]},"r":610354376},{"a":5,"g":{"t":18,"p":[23,null,null]},"r":917500111},{"a":1,"g":{"b":13,"p":[18,null,null]},"r":401650914},{"a":1,"g":{"b":17,"p":[18,null,null]},"r":787750630},{"a":6,"g":{"t":13},"r":926359557},{"a":1,"g":{"b":14,"p":[13,null,null]},"r":443391565},{"a":1,"g":{"b":12,"p":[13,null,null]},"r":285567498},{"a":6,"g":{"t":14},"r":152038804},{"a":1,"g":{"b":19,"p":[14,null,null]},"r":81255802},{"a":1,"g":{"b":9,"p":[14,null,null]},"r":243091363},{"a":1,"g":{"b":8,"p":[9,null,null]},"r":85632325},{"a":1,"g":{"b":4,"p":[9,null,null]},"r":564178102},{"a":5,"g":{"t":12,"p":[13,null,null]},"r":499626361},{"a":5,"g":{"t":12,"p":[13,null,null]},"r":275087685},{"a":1,"g":{"b":11,"p":[12,null,null]},"r":818957687},{"a":5,"g":{"t":11,"p":[12,null,null]},"r":888464132},{"a":1,"g":{"b":6,"p":[11,null,null]},"r":520962366},{"a":1,"g":{"b":16,"p":[11,null,null]},"r":997485155},{"a":1,"g":{"b":5,"p":[6,null,null]},"r":871698480},{"a":1,"g":{"b":21,"p":[16,null,null]},"r":352530928},{"a":1,"g":{"b":10,"p":[5,null,null]},"r":339760145},{"a":1,"g":{"b":0,"p":[5,null,null]},"r":849874452},{"a":1,"g":{"b":15,"p":[10,null,null]},"r":810030241},{"a":1,"g":{"b":20,"p":[21,null,null]},"r":408042264},{"a":1,"g":{"b":26,"p":[21,null,null]},"r":347035662},{"a":1,"g":{"b":25,"p":[20,null,null]},"r":601593820},{"a":1,"g":{"b":27,"p":[26,null,null]},"r":9932503},{"a":5,"g":{"t":0,"p":[5,null,null]},"r":432925531},{"a":1,"g":{"b":1,"p":[0,null,null]},"r":581018259},{"a":1,"g":{"b":2,"p":[1,null,null]},"r":313671457},{"a":1,"g":{"b":3,"p":[2,null,null]},"r":245860898},{"a":1,"g":{"b":7,"p":[2,null,null]},"r":422139369},{"a":6,"g":{"t":1},"r":951094487}],[{"a":3,"g":{"s":2},"r":489742797},{"a":1,"g":{"b":12,"p":[7,null,null]},"r":468434827},{"a":1,"g":{"b":6,"p":[7,null,null]},"r":35160467},{"a":1,"g":{"b":5,"p":[6,null,null]},"r":564876756},{"a":5,"g":{"t":5,"p":[6,null,null]},"r":125757531},{"a":1,"g":{"b":0,"p":[5,null,null]},"r":744371291},{"a":1,"g":{"b":10,"p":[5,null,null]},"r":496759718},{"a":1,"g":{"b":1,"p":[0,null,null]},"r":372578487},{"a":1,"g":{"b":3,"p":[2,null,null]},"r":964458009},{"a":1,"g":{"b":8,"p":[3,null,null]},"r":710672889},{"a":1,"g":{"b":9,"p":[8,null,null]},"r":461968992},{"a":1,"g":{"b":4,"p":[9,null,null]},"r":321975337},{"a":1,"g":{"b":14,"p":[9,null,null]},"r":399608028},{"a":6,"g":{"t":4},"r":387159516},{"a":6,"g":{"t":14},"r":57738751},{"a":1,"g":{"b":19,"p":[14,null,null]},"r":611753668},{"a":1,"g":{"b":13,"p":[14,null,null]},"r":967282569},{"a":1,"g":{"b":18,"p":[13,null,null]},"r":157555583},{"a":1,"g":{"b":17,"p":[18,null,null]},"r":797891503},{"a":1,"g":{"b":15,"p":[10,null,null]},"r":770061025},{"a":5,"g":{"t":15,"p":[10,null,null]},"r":310018259},{"a":6,"g":{"t":2},"r":688552670}],[{"a":1,"g":{"b":28,"p":[29,null,null]},"r":910735304},{"a":1,"g":{"b":27,"p":[28,null,null]},"r":506811321},{"a":1,"g":{"b":23,"p":[28,null,null]},"r":401686421},{"a":1,"g":{"b":26,"p":[27,null,null]},"r":783388295},{"a":1,"g":{"b":21,"p":[26,null,null]},"r":723713074},{"a":1,"g":{"b":25,"p":[26,null,null]},"r":700421414},{"a":5,"g":{"t":21,"p":[26,null,null]},"r":55099139},{"a":1,"g":{"b":16,"p":[21,null,null]},"r":944999884},{"a":1,"g":{"b":20,"p":[21,null,null]},"r":11403851},{"a":1,"g":{"b":22,"p":[21,null,null]},"r":342410084},{"a":1,"g":{"b":17,"p":[16,null,null]},"r":493508993},{"a":1,"g":{"b":11,"p":[16,null,null]},"r":329147565},{"a":1,"g":{"b":15,"p":[16,null,null]},"r":849913299},{"a":1,"g":{"b":12,"p":[11,null,null]},"r":655272034},{"a":1,"g":{"b":6,"p":[11,null,null]},"r":722130361},{"a":1,"g":{"b":10,"p":[11,null,null]},"r":152601189},{"a":1,"g":{"b":13,"p":[12,null,null]},"r":824073313},{"a":5,"g":{"t":6,"p":[11,null,null]},"r":616025613},{"a":1,"g":{"b":1,"p":[6,null,null]},"r":735497880},{"a":1,"g":{"b":7,"p":[6,null,null]},"r":967706075},{"a":6,"g":{"t":7},"r":890819517}],[{"a":1,"g":{"b":22,"p":[27,null,null]},"r":199650641},{"a":6,"g":{"t":22},"r":978676075},{"a":3,"g":{"s":2},"r":600198911},{"a":1,"g":{"b":17,"p":[22,null,null]},"r":454765435},{"a":5,"g":{"t":17,"p":[22,null,null]},"r":825821736},{"a":1,"g":{"b":12,"p":[17,null,null]},"r":51127327},{"a":1,"g":{"b":7,"p":[12,null,null]},"r":445045568},{"a":1,"g":{"b":6,"p":[7,null,null]},"r":338559543},{"a":6,"g":{"t":5},"r":148642536}],[{"a":1,"g":{"b":18,"p":[13,null,null]},"r":377220521},{"a":1,"g":{"b":12,"p":[13,null,null]},"r":583013854},{"a":1,"g":{"b":11,"p":[12,null,null]},"r":879206014},{"a":5,"g":{"t":11,"p":[12,null,null]},"r":777429319},{"a":5,"g":{"t":11,"p":[12,null,null]},"r":113505453},{"a":1,"g":{"b":10,"p":[11,null,null]},"r":860012072},{"a":1,"g":{"b":16,"p":[11,null,null]},"r":127867711},{"a":1,"g":{"b":21,"p":[16,null,null]},"r":133452332},{"a":5,"g":{"t":22,"p":[21,null,null]},"r":659870863},{"a":5,"g":{"t":26,"p":[21,null,null]},"r":546734742},{"a":1,"g":{"b":5,"p":[10,null,null]},"r":294153936},{"a":5,"g":{"t":5,"p":[10,null,null]},"r":716189110},{"a":1,"g":{"b":0,"p":[5,null,null]},"r":829903244},{"a":1,"g":{"b":1,"p":[0,null,null]},"r":169535159},{"a":1,"g":{"b":6,"p":[1,null,null]},"r":775246762},{"a":1,"g":{"b":2,"p":[1,null,null]},"r":581371677},{"a":1,"g":{"b":3,"p":[2,null,null]},"r":955739042},{"a":1,"g":{"b":8,"p":[3,null,null]},"r":364155087},{"a":5,"g":{"t":7,"p":[8,null,null]},"r":598562872},{"a":1,"g":{"b":4,"p":[3,null,null]},"r":564918362},{"a":1,"g":{"b":9,"p":[4,null,null]},"r":365790773},{"a":5,"g":{"t":9,"p":[4,null,null]},"r":10433278},{"a":1,"g":{"b":14,"p":[9,null,null]},"r":460311342},{"a":5,"g":{"t":14,"p":[9,null,null]},"r":914924548},{"a":5,"g":{"t":19,"p":[14,null,null]},"r":693758858},{"a":1,"g":{"b":23,"p":[22,null,null]},"r":664903033},{"a":1,"g":{"b":28,"p":[23,null,null]},"r":472269196},{"a":6,"g":{"t":12},"r":826012580}]],"status":"Replay Failed","time":1394713426.815,"pid":29294,"server":"0","logType":"Info"}
  d = new Dungeon(log.initial_data)
  d.initialize()
  d.replayActionLog(log.replay)
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
