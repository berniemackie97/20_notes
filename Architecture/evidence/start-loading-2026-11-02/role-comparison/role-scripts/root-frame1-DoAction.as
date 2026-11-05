function getMsg(prop, oldVal, newVal)
{
   var _loc3_ = newVal.split("|");
   var _loc2_ = _loc3_[0];
   var _loc1_ = _loc3_[1];
   showTrace("getMsg:" + _loc2_ + "," + _loc1_);
   switch(_loc2_)
   {
      case "PATH":
         getPath(_loc1_);
         break;
      case "ERROR":
         getError(_loc1_);
         break;
      case "CREATEFAIL":
         getError(_loc1_);
         break;
      case "EXIT":
         getExit();
         break;
      case "PROGRESS":
         getProgress(_loc1_);
         break;
      case "USERACCOUNT":
         getUserAccount(_loc1_);
         break;
      case "LOADING_TRACE":
         getLoadTace(_loc1_);
         break;
      case "BANNED":
         getBanned(_loc1_);
         break;
      case "HIDERETURNBTN":
         returnBtnHide(sMsg);
      default:
         return;
   }
}
function submit()
{
   var _loc1_ = _root;
   var _loc1 = this;
   fscommand("CMD_NICK",_loc1_.sUserName);
   fscommand("CMD_BODYSIZE",_loc1_.nSelectBody - 1);
   fscommand("CMD_VOCATION",_loc1_.nSelectJob - 1);
   fscommand("CMD_ENTERGAME","1");
   trace("ming:" + sUserName);
}
function getUserAccount(sMsg)
{
   _root.userAccount = sMsg;
}
function back2Login()
{
   fscommand("CMD_DRIVERBACK");
}
function getLoadTace(sMsg)
{
   _root.inGameMC.getLoadingTace(sMsg);
}
function getBanned(sMsg)
{
}
function getError(sError)
{
   var _loc1_ = _root;
   _loc1_.nError = 0;
   _loc1_.sErrorTxt = sError;
   _loc1_.errorMC.gotoAndPlay(2);
   _loc1_.inGameMC.gotoAndStop(1);
}
function getPath(newVal)
{
   if(newVal == "")
   {
      mainPath = "";
   }
   else
   {
      mainPath = newVal + "/";
   }
   ini = new CIni(mainPath + "ini/selectCharacter.ini");
   _root.iniLoaded(ini);
}
function getExit()
{
   var _loc1_ = _root;
   if(inGameMC.isLoading)
   {
      if(!_loc1_.quitWindow2.isShow)
      {
         _loc1_.quitWindow2.play();
      }
   }
   else if(!_loc1_.quitWindow.isShow)
   {
      _loc1_.quitWindow.play();
   }
}
function pressEnterNormal()
{
   trace("normal");
}
function pressEnterError()
{
   trace("error");
}
function pressEnter()
{
   if(inGameMC.isLoading)
   {
      trace("enter1");
   }
   else if(!isErrorPanelShow)
   {
      pressEnterNormal();
      isErrorPanelShow = true;
   }
   else
   {
      pressEnterError();
      isErrorPanelShow = false;
   }
}
function pressEscNormal()
{
}
function pressEscError()
{
}
function pressEsc()
{
   if(!inGameMC.isLoading)
   {
      if(!isErrorPanelShow)
      {
         pressEscNormal();
      }
      else
      {
         pressEscError();
      }
   }
}
function turnToNewline(str)
{
   var _loc3_ = str.split("\\n");
   var _loc2_ = _loc3_.join("\n");
   var _loc1_ = _loc2_.split("~");
   _loc1_ = _loc1_.join(" ");
   return _loc1_;
}
function characterGetPath()
{
   _root.characterInAndOut.getPath(_root.mainPath);
}
function iniLoaded(ini)
{
   var _loc2_ = _root;
   var _loc3_ = this;
   ini.onLoadSuccess = function()
   {
      var _loc2_ = _root;
      var _loc3_ = this;
      var _loc1_ = _loc3_.data;
      _loc2_.play();
      var nX1 = _loc1_.logo.xPos;
      var nY1 = _loc1_.logo.yPos;
      _loc2_.logoMC.loadMovie(_loc2_.mainPath + "data/main/flash/logo.swf");
      _loc2_.logoMC._x = nX1;
      _loc2_.logoMC._y = nY1;
      _loc2_.characterInAndOut.loadMovie(_loc2_.mainPath + "data/main/flash/characterInAndOut.swf");
      for(var i in _loc1_.tip)
      {
         oTipData[i] = _loc1_.tip[i];
      }
      for(var infoI in _loc1_.info)
      {
         _loc2_.infoData[infoI] = _loc3_.data.info[infoI];
      }
      for(var apI in _loc1_.affirmPanel)
      {
         _loc2_.affirmPanelData[apI] = _loc3_.data.affirmPanel[apI];
      }
      _loc2_.soundVol = _loc1_.sound.volume;
      for(var i in _loc1_.bodySelection)
      {
         snd_bs[i] = new Sound();
         snd_bs[i].loadSound(_loc2_.mainPath + "sound/" + _loc1_.bodySelection[i]);
         snd_bs[i].onLoad = function(success)
         {
            if(!success)
            {
            }
         };
      }
      for(var i in _loc1_.classSelection)
      {
         snd_cs[i] = new Sound();
         snd_cs[i].loadSound(_loc2_.mainPath + "sound/" + _loc1_.classSelection[i]);
         snd_cs[i].onLoad = function(success)
         {
            if(!success)
            {
            }
         };
      }
      for(var i in _loc1_.dialogBox)
      {
         snd_db[i] = new Sound();
         snd_db[i].loadSound(_loc2_.mainPath + "sound/" + _loc1_.dialogBox[i]);
         snd_db[i].onLoad = function(success)
         {
            if(!success)
            {
            }
         };
      }
      delete data;
   };
}
function returnBtnHide(sMsg)
{
   if(sMsg == "0")
   {
      isBtnReturnHide = false;
   }
   else if(sMsg == "1")
   {
      isBtnReturnHide = true;
   }
}
function getProgress(sMsg)
{
   if(sMsg == "1")
   {
      this.inGameMC.play();
   }
   else if(sMsg == "80")
   {
      this.inGameMC.play();
   }
}
stop();
_lockroot = true;
_quality = "best";
_focusrect = false;
stop();
var nStageType = 0;
var nSelectJob = 0;
var nSelectBody = 0;
var sUserName = "";
var tip = new CTxtTip(9999);
var oTipData = new Object();
var nError = 0;
var VCTOFLASH = "";
watch("VCTOFLASH",getMsg);
var affirmPanelData = new Object();
var infoData = new Object();
var mainPath = "";
var ini;
_root.createEmptyMovieClip("keyListener",333);
var enterIsDown = false;
var escIsDown = false;
var isErrorPanelShow = false;
keyListener.onEnterFrame = function()
{
   if(Key.isDown(27))
   {
      if(!escIsDown)
      {
         escIsDown = true;
         pressEsc();
      }
   }
   else if(escIsDown)
   {
      escIsDown = false;
   }
   if(Key.isDown(13))
   {
      if(!enterIsDown)
      {
         enterIsDown = true;
         pressEnter();
      }
   }
   else if(enterIsDown)
   {
      enterIsDown = false;
   }
};
var snd_bs = new Object();
var snd_cs = new Object();
var snd_db = new Object();
var click_None = new Sound();
var soundVol = 0;
_global.playSound = function(sIniSnd, sSndHandle)
{
   var _loc1_ = _root[sIniSnd][sSndHandle];
   if(!_loc1_)
   {
      trace("播放声音错误：(_root." + sIniSnd + "." + sSndHandle + ")");
   }
   else
   {
      _loc1_.setVolume(_root.soundVol);
      _loc1_.start();
   }
};
var snd_ss = new Object();
this.createEmptyMovieClip("musicMC",234);
var isBtnReturnHide = true;
