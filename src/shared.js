/**
 * User: hammer
 * Date: 13-9-13
 * Time: 下午3:24
 */
/*** TABLE NAMES ***/
TABLE_ROLE = "roles";
TABLE_ITEM = "items";
TABLE_STAGE = "stages";
TABLE_EFFECT = "effects";
TABLE_CARD = "cards";
TABLE_SKILL = "skills";
TABLE_VERSION = "version";
TABLE_LEVEL = "levels";
TABLE_DUNGEON = "dungeons";
TABLE_UPGRADE = "upgrade";
TABLE_ENHANCE = "enhance";
TABLE_QUEST = "quests";
TABLE_STORE = "store";
TABLE_CONFIG = "config";
TABLE_DROP = "drop";
TABLE_DIALOGUE = "dialogue";
TABLE_CAMPAIGN = "campaign";
TABLE_VIP = "vip";
TABLE_TRIGGER = "triggers";
TABLE_BROADCAST = "broadcast";
TABLE_LEADBOARD = "leadboard";
TABLE_FACTION = "faction";
TABLE_COSTS = "costs";
TABLE_DP = "dailyPrize";

/*** GAME CONSTANTS ***/
ItemId_RevivePotion = 540;

/*** RPC COMMANDS ***/
RET_OK = 0;
RET_NotEnoughGold = 1;
RET_NotEnoughDiamond = 2;
RET_NotEnoughEnergy = 3;
RET_RoleClassNotMatch = 4;
RET_RoleLevelNotMatch = 5;
RET_PlayerNotExisit = 6;
RET_ItemNotExist = 7;
RET_InventoryFull = 8;
RET_InsufficientEquipXp = 9;
RET_NoEquip = 10;
RET_NoEnhanceStone = 11;
RET_EquipCantUpgrade = 12;
RET_Unknown = 13;
RET_NotEnoughItem = 14;
RET_TooMuchChat = 15;
RET_ServerError = 16;
RET_FriendListFull = 17;
RET_OtherFriendListFull = 18;
RET_ExceedMaxEnhanceLevel = 19;
RET_SyncError = 20;
RET_EnhanceFailed = 21;
RET_DungeonNotExist = 22;
RET_StageIsLocked = 23;
RET_AppVersionNotMatch = 24;
RET_ResourceVersionNotMatch = 25;
RET_AccountHaveNoHero = 26;
RET_WrongAccountID = 27;
RET_InvalidName = 28;
RET_PlayerNotExists = 29;
RET_NameTaken = 30;
RET_NoKey = 31;
RET_CantInvite = 32;
RET_Issue33 = 33;
RET_LoginFailed = 34;
RET_Issue35 = 35;
RET_Issue36 = 36;
RET_Issue37 = 37;
RET_Issue38 = 38;
RET_VipLevelIsLow = 39;
RET_SoldOut = 40;
RET_Issue41 = 41;
RET_LoginByAnotherDevice = 42;
RET_NewVersionArrived = 43;
RET_SessionOutOfDate = 44;
RET_NeedTeammate = 45;
RET_NeedReceipt = 46;
RET_InsufficientIngredient = 47;
RET_InvalidPaymentInfo = 48;
RET_SweepPowerNotEnough = 49;
RET_NotEnoughTimes = 50;
RET_CantReceivePkAward = 51;
ErrorMsgs = [
    "操作成功",
    "金币数量不足",
    "宝石数量不足",
    "精力值不足",
    "角色职业不符合要求",
    "角色等级不符合要求",
    "玩家不存在",
    "道具不存在",
    "背包已满",
    "装备熟练度不足",
    "缺少装备",
    "缺少强化宝石",
    "装备无法再次升级",
    "发生了什么错误",
    "道具数量不足",
    "聊天信息发送过于频繁，请稍等片刻",
    "服务器状态异常，请稍后再试",
    "你的好友列表已经满了",
    "对方的好友列表已经满了",
    "这个属性不能再强化了",
    "与服务器数据同步出错，请重新登陆",
    "强化失败",
    "副本不存在",
    "关卡尚未解锁",
    "程序版本不匹配",
    "资源版本不匹配",
    "需要创建角色",
    "错误的登录信息",
    "不允许的名字",
    "角色不存在",
    "名字已被占用",
    "没有匹配的钥匙",
    "无法添加对方为好友",
    "错误:33",
    "登录失败",
    "错误:35",
    "错误:36",
    "错误:37",
    "错误:38",
    "VIP等级不足",
    "物品已经售完",
    "错误:41",
    "从另外一个设备登录",
    "有新版本更新，请重新登录",
    "与服务器断开连接",
    "Need Teammate",
    "缺少配方",
    "缺少材料",
    "付费信息错误，请联系工作人员",
    "战斗力不足",
    "挑战次数以用尽",
    "无法领取PK奖励",
];

/*** ITEM CATEGORY ***/
ITEM_USE = 0;//使用（无）
ITEM_EQUIPMENT = 1;//装备 (绿）
ITEM_GEM = 2;//宝石（紫）
ITEM_RECIPE = 3;//配方（蓝）
ITEM_USELESS = 4;//无用的（灰）

/*** Subcategory of ITEM_EQUIPMENT ***/
EquipSlot_MainHand = 0;//主手装备
EquipSlot_SecondHand = 1;//副手装备
EquipSlot_Chest = 2;//胸甲装备
EquipSlot_Finger = 3;//戒指装备
EquipSlot_Legs = 4;//腿甲装备
EquipSlot_Neck = 5;//护符装备
EquipSlot_Face = 6;//脸
EquipSlot_Eye = 7;//眼镜
EquipSlot_Brow = 8;//眉毛
EquipSlot_Hair = 9;//头发

/*** Subcategory of ITEM_EQUIPMENT ***/
EquipSlot_StoreMainHand = 10;//主手
EquipSlot_StoreSecondHand = 11;//副手
EquipSlot_StoreSuit = 12;//套装
EquipSlot_StoreHead = 13;//头盔
EquipSlot_StoreHair = 14;//发型
EquipSlot_StoreGear = 15;//头饰

/*** 装备类型 ***/
ITEMSTATUS_NONE = 0;
ITEMSTATUS_EQUIPED = 1;

/*** Subcategory of ITEM_USE ***/
ItemUse_ItemPack = 0;
ItemUse_Function = 1;
ItemUse_TreasureChest = 2;

/*** Subcategory of ENHANCE ***/
ENHANCE_SEVEN = 0;
ENHANCE_FIVE = 1;
ENHANCE_THREE = 2;
ENHANCE_ATTACK = 3;
ENHANCE_HEALTH = 4;
ENHANCE_SPEED = 5;
ENHANCE_CRITICAL = 6;
ENHANCE_STRONG = 7;
ENHANCE_ACCURACY = 8;
ENHANCE_REACTIVITY = 9;
ENHANCE_VOID = 10;
ENHANCE_COUNT = 11;

/*** Enhance Result ***/
RES_ATTACK = 0;
RES_HEALTH = 1;
RES_SPEED = 2;
RES_CRITICAL = 3;
RES_STRONG = 4;
RES_ACCURACY = 5;
RES_REACTIVITY = 6;
RES_LEECH = 7;
RES_REFLECT = 8;
RES_COUNTER = 9;
RES_STUN = 10;
RES_CRIDMG = 11;
RES_GOLD = 12;
RES_WXP = 13;
RES_EXP = 14;

Sweep_Vip_Level = 3;

LOGIN_ACCOUNT_TYPE_TG = 0;
LOGIN_ACCOUNT_TYPE_AD = 1;
LOGIN_ACCOUNT_TYPE_PP =  2;
LOGIN_ACCOUNT_TYPE_91 =  3;
LOGIN_ACCOUNT_TYPE_KY =  4;
LOGIN_ACCOUNT_TYPE_GAMECENTER =  5;

Max_tutorialStage = 3;

MonthCardID = 8;

/*** Quest Status ***/
QUESTSTATUS_ONGOING = 0;
QUESTSTATUS_COMPLETE = 1;

/*** Prize Type ***/
PRIZETYPE_ITEM = 0;
PRIZETYPE_GOLD = 1;
PRIZETYPE_DIAMOND = 2;
PRIZETYPE_EXP = 3;
PRIZETYPE_WXP = 4;
PRIZETYPE_FUNCTION = 5;

/*** FUNCTION-Prize Type ***/
FPT_DUOMUDAILLY = 0;

/*** Message Type ***/
MESSAGETYPE_PLAYER = 0;
MESSAGETYPE_SYSTEM = 1;
MESSAGETYPE_BROADCAST = 2;
MESSAGETYPE_WHISPER = 3;

MESSAGE_REWARD_TYPE_OFFLINE = 0;
MESSAGE_REWARD_TYPE_SYSTEM = 1;

/*** Broadcast Type ***/
BROADCAST_TREASURE_CHEST = 0;
BROADCAST_INFINITE_LEVEL = 1;
BROADCAST_ENHANCE = 2;
BROADCAST_ITEM_LEVEL = 3;
BROADCAST_PLAYER_LEVEL = 4;
BROADCAST_CRAFT = 5;

/*** FEATURES ***/
FEATURE_ENERGY_RECOVER = 0;
FEATURE_INVENTORY_STROAGE = 1;
FEATURE_FRIEND_STROAGE = 2;
FEATURE_FRIEND_GOLD = 3;

/*** NOTIOFICATION OP ID ***/
NTFOP_ACCEPT = 1;
NTFOP_DECLINE = 0;

Global_Card_Drop_Config = {
  "cardRate":0.2,
  "cards": [
    { "weight": 2, "type": 0 },
    { "weight": 2, "type": 1 }, 
    //{ "weight": 2, "type": 2 },
    { "weight": 2, "type": 3 },
    { "weight": 1, "type": 4 },
    { "weight": 2, "type": 5 },
    { "weight": 2, "type": 6 },
    { "weight": 2, "type": 7 },
    { "weight": 2, "type": 8 }
  ]
};
