{implementing} = require('./helper')
{Serializer, registerConstructor} = require('./serializer')
{DBWrapper } = require('./dbWrapper')
{Shop} = require('./shop')
{currentTime, verify} = require('./timeUtils')
underscore = require('./underscore')


class Upgradeable
  constructor: (@level=0) ->

  upgrade: (oprator,args) ->
    return {ret:RET_Not_Upgradeable} unless @canUpgrade(oprator,args)
    cost =  @upgradeCost(@level)
    return {ret:RET_Not_Upgradeable} unless cost?
    ntf = oprator.claimCost(cost)
    if ntf?
      ntf = nft.concat(@customCost(oprator,args))
      @level += 1
    return ntf

  currentLevel:() ->
    @level


  #override
  upgradeCost: (level) -> null
  canUpgrade: (oprator,args) -> true
  #!!! this function will cost other resource ,
  #if you over write this function, please make sure 
  #when canUpgrade return true,customCost shouldn't fail to claim cost 
  customCost : () -> []

exports.Upgradeable = Upgradeable

class Authority
  constructor: (id, cfg, bindee) ->
    @config = @_getConfig(id)
    @_bindFunc(cfg,bindee)

  check: (role,action) ->
    @config[role]?[action] ? false

  _getConfig: (id) ->
    queryTable(TABLE_AUTHOTITY,id).tab
  
  _bindFunc:(cfg, bindee) ->
    genFunc= (originF, name) ->
      (role, args...) ->
        if @check(role,action)
          return originF.apply(@,args)
        else
          return {ret:RET_AuthorityLimit}


    bindee.__originFunc={}
    for funcInClass, action of cfg
      if typeof bindee[funcInClass] isnt 'function'
        throw 'no such method'
      bindee.__originFunc[funcInClass] = bindee[funcInClass]
      bindee[funcInClass] = genFunc(bindee.__originFunc[funcInClass] , funcInClass)
      
exports.Authority = Authority
Modifier = implementing(Serializer, Upgradeable, class _Modifier
  constructor: (data) ->
    cfg ={
      type:''
      activeTimeStamp:0
      level:0 #Upgradeable
    }
    super({
      Upgradeable:[],
      Serializer: [data, cfg,{}]
    })
 

  getType: () -> @type
  getConfig: (key) ->
    queryTable(TABLE_GUILD,'modifier')?[@type]
  
  currentTime:currentTime

  active: (oprator) ->
    cost = @getConfig('active').cost
    ntf = oprator.claimCost(cost)
    if ntf?
      @activeTimeStamp = @currentTime()
    return ntf

  _isActive: () ->
    return @activeTimeStamp isnt 0 and verify(
      @currentTime()
      ,@getConfig('active').stayOpen
      , {date:{activeTime:@activeTimeStamp }})

  _checkTarget : (target) -> @getConfig('target').indexOf(target.faction) isnt -1

  applyModifier: (event, target) ->
    if @_isActive() and  @_checkTarget(target)
      return @getConfig('modifyData').reduce((acc,modifier) =>
        mValue = modifier.value[@level] ? underscore.last(modifier.value)
        if event is modifier.event and acc[modifier.type]? and mValue
          acc[modifier.type] = Math.ceil(acc[modifier.type]* mValue)
        return acc
      ,target)
     return target


  #override Upgradeable
  upgradeCost: (level) ->
    @getConfig('upgradeCost')?[level]
    super()

)
exports.Modifier = Modifier

class Building extends Serializer
  constructor: (data) ->
    cfg = {
        modifierLst:[]
    }
    super(data, cfg, {})

  upgradeBuilding :(type,oprator) ->
    modifier = @getModifierByType(type)
    return {ret: RET_InvalidateModifier} unless modifier?
    return modifier.upgrade(oprator)

  addBuilding :(type,oprator) ->
    return {ret:RET_SameBuildingExsit} if @getModifierByType(type)?
    cost = @getBuildCost(type)
    ntf = oprator.claimCost(cost)
    return {ret: RET_ItemNotExist} unless ntf?
    @modifierLst.push(new Modifier(type))
    return {ret:RET_OK,ntf:ntf}

  active: (type, oprator) ->
    modifier = @getModifierByType(type)
    return {ret: RET_InvalidateModifier} unless modifier?
    modifier.active(oprator)
    
  applyModifier: (event,target) ->
    modifierLst.reduce((acc, modifier) ->
      modifier.applyModifier(event,acc)
    ,target)
  getBuildCost: (type) ->
    queryTable(TABLE_GUILD,'modifier')[type]?upgradeCost[0]

  getModifierByType: (type) ->
    for modifier in @modifierLst
      return modifier if modifier.getType() is type
    return null

exports.Building = Building


class GuildMember extends Serializer
  constructor: (data) ->
    cfg = {
      max: 20
      playerLst:[] # {name,lastLogin,role}
    }
    super(data, cfg, {})

  #player managment
  invite: (admin, name, id,callback) ->
    msg = {type:  MESSAGE_TYPE_GuildInvite, name: this.name}
    async.series([
      (cb) ->
        if id?
          dbLib.getPlayerNameByID(id, gServerName, (err, theName) ->
            if theName then name = theName
            cb(err)
          )
        else
          cb(null)
      (cb) => if name is admin.name then cb(new Error(RET_CantInvite)) else cb (null),
      (cb) => if @isHave(name) then cb(new Error(RET_OK)) else cb (null),
      (cb) -> dbLib.playerExistenceCheck(name, cb),
      (cb) -> dbLib.deliverMessage(name, msg, cb, null, true),
    ], (err, result) ->
      err = new Error(RET_OK) unless err?
      if callback then callback(err)
    )


  join: (player,callback) ->

  kick: (admin,name,id,msg,callback) ->


  leave: (name,callback) ->
    @playerLst = @playerLst.filter((member) -> member.name isnt name)

  add: (name,id,callback) ->

  #player action
  onMemberLogin: (name) ->

  query: (type) ->
    switch type
      when 'max'
        return @_getMaxMemberCount()
      when 'members'
        @playerLst

  isHave: (name) ->
    underscore.findIndex(@playerLst, (member) -> member.name is name) isnt -1
  

  #(type, admin, target, memberRecoder) ->
  _getMaxMemberCount: () ->
    return @max
 
Guild = implementing(Serializer, Upgradeable, class _Guild
  constructor: (data) ->
    cfg ={
      id:-1
      building: Building
      shop: Shop
      store:Bag
      memberLst: GuildMember
      xp:0
    }
    super({
      Upgradeable:[],
      Serializer: [data, cfg,{}]
    })
  queryInfo: (type) ->

  onUseEnergy: (name,value) ->
    if @memberLst.isHave(name)
      @_addXp(value)


  memberOp: () ->
    @memberLst.memberOp()
  _addXp: (value) ->
    @xp += value if value > 0
  _subXp: (value) ->
    return false unless value >= 0
    temp = @xp - value
    return false if temp < 0
    @xp = temp
    return true
)

class GuildManager extends DBWrapper
  constructor: (data) ->
    cfg ={
      guildLst:[],
      playerRef:{}
      nextGid: -1
    }
    super(data,cfg, {})

  _createGuild: (player) ->
  joinGuild: (player) ->
  destroyGuild: (player) ->

  queryInfo: (type,subType, gid) ->
    switch  type
      when 'guild'
        switch arg.que
          when 'info'
            {
              NTF:Event_GuildInfo
              arg:[
                {
                  bid:1,nam:'b1',max:20,cnt:10,lvl:1,xp:20
                  bud:[{typ:'gold',lvl:1} ],
                  shp:3,
                }
              ]
            }
          when 'list'
            {
              NTF:Event_GuildInfo
              arg:[
                {bid:1,nam:'b1',max:20,cnt:10,lvl:1,}
                {bid:2,nam:'b2',max:20,cnt:10,lvl:1}
              ]
            }
          when 'inv'
            {
              NTF:Event_InventoryUpdateItem
            }
      when 'member'
        #src cnt 
        ret = getBasicInfo() #gst ->role


  buildingOp: (type, building, player,args) ->

  memberOp: (type, admin, target) ->
    guild = @findePlayerGuild(admin.name)
    return {ret:RET_InvalidGuild} unless guild?
    guild.memberOp(type, admin, target, @)
    
  _getGuildByGid: (gid) ->
    guild = @guildLst[gid]
    if guild? and not guild.isValidate()
      @guildLst[gid] =  guild = null
    return guild
      
  _getNextGid: () ->
    gid = underscore.findIndex(@guildLst, (guild) -> not guild.isValidate())
    return gid unless gid is -1
    @nextGid += 1
    return @nextGid

  buildingOp: (type,building,player,args) ->

  guildOp: (type, gid, player) ->
    switch type
      when 'create'
        return {ret:RET_InvalidOp} if player.getGuildId()?
        return @_createGuild(player)
      when 'delete'
        return {ret:RET_InvalidOp} unless player.getGuildId()?
        return @_deleteGuild(player)
      when 'upgrade'
        1
  findePlayerGuild: (name) ->
    @_getGuildByGid(@playerRef[name])

  registNewGuildMember:(name, gid) ->
    return {ret:RET_InvalidOp} if  @playerRef[name]?
    @playerRef[name] = gid

  unregistNewGuildMember: (name) ->
    if @playerRef[name]?
      delete @playerRef[name]


exports.GuildManager = GuildManager
