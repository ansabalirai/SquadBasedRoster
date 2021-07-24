//---------------------------------------------------------------------------------------
//  FILE:    UIScreenListener_AvengerHUD
//  AUTHOR:  Amineri / Pavonis Interactive
//
//  PURPOSE: This class listens UIAvengerHUD and adds a BARRACKS to the shortcuts
//--------------------------------------------------------------------------------------- 

class UIScreenListener_AvengerHUD extends UIScreenListener dependson(UIAvengerShortcuts);

var bool bDoneOncePerSessionUpdates;

delegate MsgCallback(optional StateObjectReference Facility);

// This event is triggered after a screen is initialized
event OnInit(UIScreen Screen)
{
    //`LWOUTPOSTMGR.SetupOutpostInterface();
    class'XComGameState_SBRSquadManager'.static.GetSquadManager().SetupSquadManagerInterface();
}

defaultproperties
{
	// Leaving this assigned to none will cause every screen to trigger its signals on this class
	ScreenClass = UIAvengerHUD;
}
