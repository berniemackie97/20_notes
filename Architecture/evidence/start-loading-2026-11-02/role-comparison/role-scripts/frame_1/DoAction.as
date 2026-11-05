function getLoadingTace(sMsg)
{
   _visible = true;
   txtMsg1.text = sMsg;
   trace("getLoadingTace :    " + sMsg);
}
stop();
isLoading = false;
_visible = false;
