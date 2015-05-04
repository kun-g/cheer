{addItemTo,implementing,claimCost} = require('./helper')
{Serializer, registerConstructor} = require('./serializer')
{DBWrapper } = require('./dbWrapper')
{Shop} = require('./shop')
{Bag} = require('./container')
dbLib = require('./db')
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
      @level += 1
      @afterUpgrade(@level)
    return ntf

  currentLevel:() ->
    @level


  #override
  upgradeCost: (level) -> null
  canUpgrade: (oprator,args) -> true
  afterUpgrade:(level) ->null
exports.Upgradeable = Upgradeable

class Authority
  constructor: (id, cfg, bindee,@debug) ->
    @config = @_getConfig(id)
    @_bindFunc(cfg,bindee)

  check: (role,action) ->
    return @debug if @debug?
    @config[role]?[action] ? false

  _getConfig: (id) ->
    queryTable(TABLE_AUTHOTITY,id).tab
  
  _bindFunc:(cfg, bindee) ->
    genFunc= (originF, name,action) ->
      (role, args...) ->
        if @check(role,action)
          return originF.apply(@,args)
        else
          return {ret:RET_AuthorityLimit}


    bindee.__originFunc={}
    for funcInClass, action of cfg
      if typeof bindee[funcInClass] isnt 'function'
        throw 'no such method =>[' + funcInClass + ']'
      bindee.__originFunc[funcInClass] = bindee[funcInClass]
      bindee[funcInClass] = genFunc(bindee.__originFunc[funcInClass] , funcInClass,action)
      
exports.Authority = Authority
Modifier = implementing(Serializer, Upgradeable, class Modifier
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
    queryTable(TABLE_GUILD,'building')?[@type][key]
  
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
    @getConfig('upgradeCost')?[level+1]

  queryInfo: ()->
    {typ:@type, lvl:@level, stm:@activeTimeStamp}
)
exports.Modifier = Modifier

Building = implementing(Serializer, Authority, class Building
  constructor: (data) ->
    cfg = {
        modifierLst:[]
    }
    super({
      Serializer:[data, cfg, {}],
      Authority:[0,{'active','upgrade'},@]
    })

  _upgradeBuilding :(oprator,type) ->
    modifier = @getModifierByType(type)
    return {ret: RET_InvalidateModifier} unless modifier?
    ntf = modifier.upgrade(oprator)
    return ntf if ntf.ret?
    return {ret: RET_OK, ntf:ntf}

  _addBuilding :(oprator,type) ->
    return {ret:RET_SameBuildingExsit} if @getModifierByType(type)?
    cost = @getBuildCost(type)
    ntf = oprator.claimCost(cost)
    return {ret: RET_ItemNotExist} unless ntf?
    @modifierLst.push(new Modifier({type:type}))
    return {ret:RET_OK,ntf:ntf}

  active: (oprator,type) ->
    modifier = @getModifierByType(type)
    return {ret: RET_InvalidateModifier} unless modifier?
    ntf = modifier.active(oprator)
    if ntf?
      ret = {ret:RET_OK,ntf:ntf}
    else
      ret = {ret:RET_NotEnoughItem}
    return ret
    
  upgrade: (oprator, type) ->
    ret = @_upgradeBuilding(oprator, type)
    if ret.ret isnt RET_InvalidateModifier
      return ret
    return @_addBuilding(oprator, type)

  applyModifier: (event,target) ->
    @modifierLst.reduce((acc, modifier) ->
      modifier.applyModifier(event,acc)
    ,target)
  getBuildCost: (type) ->
    queryTable(TABLE_GUILD,'building')[type]?upgradeCost[0]

  getModifierByType: (type) ->
    for modifier in @modifierLst
      return modifier if modifier.getType() is type
    return null
  queryInfo: ()->
    @modifierLst.map((b) -> b.queryInfo())

)

exports.Building = Building


GuildRole ={
  A:0
  B:1
  Guest:'guest'
}
GuildMember =  implementing(Serializer, Authority, class GuildMember
  constructor: (data) ->
    cfg = {
      max: 20
      playerLst:[] # {name,lastLogin,role}
      nextSeri: -1
      joinRecoder:{}
      gid: -1
    }
    super({
      Serializer:[data, cfg, {}],
      Authority:[0,{'join','invite', 'leave', 'acceptJoin'},@]})

  setGuildId:(@gid) ->

  #player managment
  _isSameRecoderExist:(msg) ->
    for k,v of @joinRecoder
      return true if underscore.isMatch(v,msg)
    return false
  _appendMemberCheck: (msg) ->
    return {ret:RET_GuildMemberLimit} if @playerLst.length >= @max
    return {ret:RET_NothingTodo} if @isHave(msg.name)
    return {ret:RET_NothingTodo} if @_isSameRecoderExist(msg)
    return {ret:RET_OK}
  invite: (admin, arg) ->
    name = arg.nam
    return {ret:RET_CantInvite} if name is admin.name
    msg = {type:  MESSAGE_TYPE_GuildInvite, name: name, gid:@gid}

    ret = @_appendMemberCheck(msg)
    return ret if ret.ret isnt RET_OK

    msg.tokenId = @addJoinRecoder(msg)
    async.series([
      (cb) -> dbLib.playerExistenceCheck(name, cb),
      (cb) -> dbLib.deliverMessage(name, msg, cb, null, true),
    ], (err, result) ->)
    return {ret:RET_OK}

  join: (me, arg) ->
    msg = {type: MESSAGE_TYPE_GuildRequestJoin, name: me.name}
    return {ret:RET_OK} if @_isSameRecoderExist(msg)
    @addJoinRecoder(msg)
    return {ret:RET_OK}

  acceptJoin: (admin,arg) ->
    name = arg.nam
    for tokenId, msg of @joinRecoder
      if msg.name is name and msg.type is  MESSAGE_TYPE_GuildRequestJoin
        if arg.ans is NTFOP_ACCEPT
          @doJoin(msg.name)
        delete @joinRecoder[tokenId]
        return {ret:RET_OK}
    return {ret:RET_OK}

  getJoinRequestLst: () ->

  doJoin: (player) ->
    return {ret:RET_OK} if @isHave(player)
    @playerLst.push({name:player,lastLogin:0,role:GuildRole.A})
    gGuildManager.registNewGuildMember(player, @gid)
    return {ret:RET_OK}
    

  leave: (player, callback) ->
    @playerLst = @playerLst.filter((member) -> member.name isnt name)
    gGuildManager.unregistGuildMember({name:player})
    callback({ret:RET_OK})

  changeRole: (name,roleType,callback) ->
    member= @_findPlayer(name)
    return {ret:RET_InvalidOp} unless member?
    member.role = roleType
    callback({ret:RET_OK})

    

  #player action
  onMemberLogin: (name) ->
    member= @_findPlayer(name)
    member.lastLogin = currentTime()
    @playerLst.sort((a,b) -> b -a)

  queryInfo: (type,args) ->
    #when 'max','cnt','joinReq'
    switch type
      when 'max'
        return @max
      when 'cnt'
        return @playerLst.length
      when 'joinReq'
        return @joinRecoder
      when 'members'
        @playerLst.slice(args.src,args.src+args.cnt)
      when 'memberByName'
        @playerLst.filter((mem) -> mem.name is args.name)[0]

  isHave: (name) ->
    @_findPlayer(name)?
  _findPlayer: (name) ->
    idx = underscore.findIndex(@playerLst, (member) -> member.name is name)
    return null if idx is -1
    return @playerLst[idx]
  

  #(type, admin, target, memberRecoder) ->

  acceptInvite: (tokenId, callback) ->
    cache = @joinRecoder[tokenId]
    callback {ret: RET_InvalidOp} unless cache?
    ret = @doJoin(chche.name)
    delete @joinRecoder[tokenId]
    return ret
  addJoinRecoder: (msg) ->
    tokenId = @_getNextSeri()
    @joinRecoder[tokenId] = msg
    return tokenId

  _getNextSeri: () ->
    @nextSeri += 1
    return @nextSeri


)
Guild = implementing(Serializer, Upgradeable, class Guild
  constructor: (data) ->
    cfg ={
      gid:-1
      nam: ''
      building: new Building()
      shop: new Shop()
      inventory:Bag(InitialBagSize)
      memberLst: new GuildMember()
      xp:0
      level:0
      gold:0
      diamond:0
      inventoryVersion:0
    }
    super({
      Upgradeable:[],
      Serializer: [data, cfg,{}]
    })
    @memberLst.setGuildId(@gid)
  applyModifier: (event, target) ->
    @building.applyModifier(event,target)
  checkCost: (prizeLst) ->
    prizeInfo.every((p) =>
      switch p.type
        when PRIZETYPE_GUILD_ITEM
          return @inventory
        when PRIZETYPE_GUILD_XP
          return true
    )
    
  claimCost: (prizeLst) ->
    helperLib.claimCost(@,cost,count)
    
  claimPrize: (prize, allorfail, prenticeIdx) ->
    helperLib.claimPrize(@, prize, allorfail, prenticeIdx)

  aquireItem:(item,  count) ->
    addItemTo(item,count,@inventory)
  queryInfo: (lst,args) ->
    result = {}
    for name in lst
      switch name
        when 'gid','nam', 'xp'
          ret = @[name]
        when 'lvl'
          ret = @level
        when 'max','cnt','joinReq', 'members','memberByName'
          ret =  @memberLst.queryInfo(name,args)
        when 'bud'
          ret = @building.queryInfo()
        when 'shp'
          ret = 1 #@shop.queryInfo()
        when 'itm'
          ret = 2
      result[name] = ret
    return result

  onUseEnergy: (name,value) ->
    if @memberLst.isHave(name)
      @_addXp(value)


  memberOp: (type, admin, arg) ->
    if admin?
      role = @_getMemberRole(admin.name)
      @memberLst[type](role, admin, arg) # with authority check
    else
      @memberLst[type](arg)# without authority check
  buildingOp:(admin, type, building) ->
    if admin?
        role = @_getMemberRole(admin.name)
        @building[type](role, admin, building) # with authority check
      else
        @building[type](admin, building)# without authority check

  _addXp: (value) ->
    @xp += value if value > 0
  _subXp: (value) ->
    return false unless value >= 0
    temp = @xp - value
    return false if temp < 0
    @xp = temp
  getGuildId: () ->
    @gid
  _getMemberRole:(name) ->
    role = @queryInfo(['memberByName'],{name:name}).memberByName?.role
    return if role? then role else GuildRole.Guest

)

class GuildManager extends DBWrapper
  constructor: (data) ->
    cfg ={
      guildLst:[],
      playerRef:{}
    }
    super(data,cfg, {})
    @setDBKeyName(guildPrifex)

  claimReward: (prizeLst, gid) ->
    guild = @findPlayerGuild({id:gid})
    return [] unless guild?
    syncKey = guild.claimReward(prizeLst)
    @_getGuildInfo([guild],syncKey)
  claimCost: (costLst, gid) ->
    guild = @findPlayerGuild({id:gid})
    return [] unless guild?
    syncKey = guild.claimCost(costLst)
    @_getGuildInfo([guild],syncKey)
  #opration
  memberOp: (type, gid, admin, arg) ->
    guild = @findPlayerGuild({id:gid})
    return {ret:RET_InvalidGuild} unless guild?
    guild.memberOp(type, admin, arg)
   
  buildingOp: (type,building,player) ->
   guild = @findPlayerGuild({id:player.getGuildId()})
   return {ret:RET_InvalidGuild} unless guild?
   guild.buildingOp(player,type, building)
  
  guildOp: (type, gid, player,arg) ->
    switch type
      when 'create'
        return {ret:RET_InvalidOp} if player.getGuildId()?
        return @_createGuild(player,arg.nam)
      when 'delete'
        return {ret:RET_InvalidOp} unless player.getGuildId()?
        return @_deleteGuild(player.name)
      when 'upgrade'
        1

  #query 
  findPlayerGuild: (nameOrId) ->
    if nameOrId.name?
      id = @playerRef[nameOrId.name]
      return null unless id?
      return @guildLst[id]
    else if nameOrId.id?
      return @guildLst[nameOrId.id]
    else if nameOrId is 'lst'
      return @guildLst.filter((g) -> g?)
    return null

  getplayerGid: (name) ->
    @playerRef[name]

  queryInfo: (type,subType, gid,args,cb) ->
    switch  type
      when 'guild'
        switch subType
          when 'info'
            guild = @findPlayerGuild({id:gid})
            guild = if guild? then [guild] else []
            ret = @_getGuildInfo(guild, ["gid", "nam", "max", "cnt", "shp", "xp", "bud", "lvl"])
          when 'list'
            ret = @_getGuildInfo(@findPlayerGuild('lst'),['gid','nam','max','cnt','lvl'])
          when 'inv'
            ret = {
              NTF:Event_InventoryUpdateItem
            }
        cb(ret)
      when 'member'
        guild = @findPlayerGuild({id:gid})
        return {ret: RET_InvalidGuild} unless guild?
        if subType is 'basicInfo'
        else
          cb({ret: RET_OK, data:guild.queryInfo([subType],args)})
        #src cnt 
        #ret = getBasicInfo() #gst ->role


  onApplyModifier:(obj, arg) ->
   guild = @findPlayerGuild({name:obj.name})
   return obj unless guild?
   guild.applyModifier(arg.evt,obj)

  #priave method
  _getGuildInfo: (guildLst, proLst) ->
    return {
      ret: RET_OK,
      data: {
          NTF:Event_GuildInfo
          arg:guildLst.map((guild) -> guild.queryInfo(proLst))
        }
    }

  registNewGuildMember:(name, gid) ->
    return {ret:RET_InvalidOp} if  @playerRef[name]?
    @playerRef[name] = gid

  unregistGuildMember: (nameOrId) ->
    name = nameOrId.name
    if name? and @playerRef[name]?
      delete @playerRef[name]
    else
      id = nameOrId.id
      for name,gid of @playerRef
        if gid is id
          delete @playerRef[name]
      
  _getNewGuidId: () ->
    gid = underscore.findIndex(@guildLst, (guild) -> not guild?)
    return gid unless gid is -1
    return @guildLst.length

  _createGuild: (player,name) ->
    cost = @_getConfig('buildCost')
    ntf = player.claimCost(cost)
    if ntf?
      gid = @_getNewGuidId()
      guild = new Guild({gid:gid, name:name})
      @guildLst[gid] = guild
      guild.memberOp('doJoin',null, player.name)
      return {ret:RET_OK, ntf:ntf}
    return {ret:RET_NotEnoughItem}
    
  _deleteGuild: (player) ->
    guild = @findPlayerGuild({name:player})
    gid = guild.getGuildId()
    @unregistGuildMember({id:gid})
    @guildLst[gid] = null
    return {ret:RET_OK}
  _getConfig: (key) ->
    queryTable(TABLE_GUILD,'guild')[key]


exports.GuildManager = GuildManager
registerConstructor(GuildManager)
registerConstructor(Modifier)
registerConstructor(Building)
registerConstructor(GuildMember)
registerConstructor(Guild)

