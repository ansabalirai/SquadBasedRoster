//---------------------------------------------------------------------------------------
//  FILE:    UIScreenListener_SquadSelect_LW
//  AUTHOR:  Rai (Amineri / Pavonis Interactive)
//
//  PURPOSE: Adds additional functionality to SquadSelect_LW (from Toolbox)
//			 Provides support for squad-editting without launching mission
//			 Also adds SBR restrictions for sending squads on missions
//--------------------------------------------------------------------------------------- 

class UIScreenListener_SquadSelect_LW extends UIScreenListener;

var localized string strSave;
var localized string strSquad;

var bool bInSquadEdit;
var GeneratedMissionData MissionData;
var StateObjectReference MissionRef;

//var config float SquadInfo_DelayedInit;

// This event is triggered after a screen is initialized
event OnInit(UIScreen Screen)
{
	local XComGameState_HeadquartersXCom XComHQ;
	local UISquadSelect SquadSelect;
	local XComGameState_SBRSquadManager SquadMgr;
	local UISquadSelect_SquadInfoPanel SquadInfo;
	local UISquadContainer SquadContainer;
	local XComGameState_MissionSite MissionState;
	local UITextContainer InfilRequirementText, MissionBriefText;
	local float RequiredInfiltrationPct;
	local string BriefingString;

	if(!Screen.IsA('UISquadSelect')) return;

	`Log("SquadBasedRoster: UIScreenListener_SquadSelect_LW: Initializing");
	
	SquadSelect = UISquadSelect(Screen);
	if(SquadSelect == none) return;

	class'LWHelpTemplate'.static.AddHelpButton_Std('SquadSelect_Help', SquadSelect, 1057, 12);

	XComHQ = `XCOMHQ;
	SquadMgr = class'XComGameState_SBRSquadManager'.static.GetSquadManager();

	SquadMgr.RefreshSquadStatus();
	// pause and resume all headquarters projects in order to refresh state
	// this is needed because exiting squad select without going on mission can result in projects being resumed w/o being paused, and they may be stale
	XComHQ.PauseProjectsForFlight();
	XComHQ.ResumeProjectsPostFlight();

	XComHQ = `XCOMHQ;
	SquadSelect.XComHQ = XComHQ; // Refresh the squad select's XComHQ since it's been updated

	MissionData = XComHQ.GetGeneratedMissionData(XComHQ.MissionRef.ObjectID);

	//check if we got here from the SquadBarracks
	bInSquadEdit = `SCREENSTACK.IsInStack(class'UIPersonnel_SquadBarracks');
	if(bInSquadEdit)
	{
		`Log("SquadBasedRoster: UIScreenListener_SquadSelect_LW: Arrived from SquadBarracks");
		if (`ISCONTROLLERACTIVE)
		{
			// KDM : Hide the 'Save Squad' button which appears while viewing a Long War squad's soldiers.
			// As an aside, I don't believe this functionality actually works.
			SquadSelect.LaunchButton.Hide();
		}
		else
		{
			SquadSelect.LaunchButton.OnClickedDelegate = OnSaveSquad;
			SquadSelect.LaunchButton.SetText(strSquad);
			SquadSelect.LaunchButton.SetTitle(strSave);
		}

		SquadSelect.m_kMissionInfo.Remove();

	} 
	else 
	{
		`Log("SquadBasedRoster: UIScreenListener_SquadSelect_LW: Arrived from mission");
		
		
		// This create the SquadContainer on a timer, to avoid creation issues that can arise when creating it immediately, when no pawn loading is present
		SquadContainer = SquadSelect.Spawn(class'UISquadContainer', SquadSelect);
		SquadContainer.CurrentSquadRef = SquadMgr.LaunchingMissionSquad;
		SquadContainer.CurrentSquadRef = SquadMgr.LastMissionSquad; //hack
		SquadContainer.DelayedInit(0.75);
		
		// Rai - Do not change the launch button since we leave it to the game to select the appropriate strings here
		//SquadSelect.LaunchButton.SetText(strStart);
		//SquadSelect.LaunchButton.SetTitle(strInfiltration);


		MissionState = XComGameState_MissionSite(`XCOMHISTORY.GetGameStateForObjectID(XComHQ.MissionRef.ObjectID));

		if (MissionState.GeneratedMission.MissionID != 0)
		{
			`Log("SquadBasedRoster: UIScreenListener_SquadSelect_LW: Setting up for an instant response mission");
			MissionRef = XComHQ.MissionRef;
			// This is an instant response mission or at least, not an infiltration or CA
			// To Do: Apply SBR restrictions here, which are:
				// 1) No more than 1 faction hero of any type
				// 2) If no faction hero selected and one is available to be deployed, show a warning pop up when clicking start mission?
				// 3) No more than 1/2 specialists of the correct type based on squad size upgrades purchased. If they are of a different type, disable the special perks added (maybe via OnPreMission hook?)


			// Show the SquadInfoPanel here
			SquadInfo = SquadSelect.Spawn(class'UISquadSelect_SquadInfoPanel', SquadSelect);
			SquadInfo.MCName = 'SquadSelect_SquadInfo';
			SquadInfo.SquadSoldiers = SquadSelect.XComHQ.Squad;
			SquadInfo.DelayedInit(0.75);			
			
		}

		else
		{
			//Differentiate between CA and infiltration mission
			if (SquadSelect.SoldierSlotCount < 6) // Hacky check which assumes that we will not have more than 5 people on a CA
			{
				`Log("SquadBasedRoster: UIScreenListener_SquadSelect_LW: Likley Setting up for a CA");
				//SquadContainer.Hide();
			}
				
			else
			{
				`Log("SquadBasedRoster: UIScreenListener_SquadSelect_LW: Likely Setting up for a infiltration mission (CI)");
				// Show the SquadInfoPanel here
				SquadInfo = SquadSelect.Spawn(class'UISquadSelect_SquadInfoPanel', SquadSelect);
				SquadInfo.MCName = 'SquadSelect_SquadInfo';
				SquadInfo.SquadSoldiers = SquadSelect.XComHQ.Squad;
				SquadInfo.DelayedInit(0.75);	
			}
				

		}
	}
}


// callback from clicking the rename squad button
function OnSquadManagerClicked(UIButton Button)
{
	local UIPersonnel_SquadBarracks kPersonnelList;
	local XComHQPresentationLayer HQPres;

	HQPres = `HQPRES;

	if (HQPres.ScreenStack.IsNotInStack(class'UIPersonnel_SquadBarracks'))
	{
		kPersonnelList = HQPres.Spawn(class'UIPersonnel_SquadBarracks', HQPres);
		kPersonnelList.bSelectSquad = true;
		HQPres.ScreenStack.Push(kPersonnelList);
	}
}

simulated function OnSaveSquad(UIButton Button)
{
	local XComGameState_HeadquartersXCom XComHQ;
	local XComGameState_SBRSquadManager SquadMgr;
	local UIPersonnel_SquadBarracks Barracks;
	local UIScreenStack ScreenStack;

	XComHQ = `XCOMHQ;
	ScreenStack = `SCREENSTACK;
	SquadMgr = class'XComGameState_SBRSquadManager'.static.GetSquadManager();
	Barracks = UIPersonnel_SquadBarracks(ScreenStack.GetScreen(class'UIPersonnel_SquadBarracks'));
	SquadMgr.GetSquad(Barracks.CurrentSquadSelection).SquadSoldiers = XComHQ.Squad;
	GetSquadSelect().CloseScreen();
	ScreenStack.PopUntil(Barracks);

}

simulated function UISquadSelect GetSquadSelect()
{
	local UIScreenStack ScreenStack;
	local int Index;
	ScreenStack = `SCREENSTACK;
	for( Index = 0; Index < ScreenStack.Screens.Length;  ++Index)
	{
		if(UISquadSelect(ScreenStack.Screens[Index]) != none )
			return UISquadSelect(ScreenStack.Screens[Index]);
	}
	return none; 
}

// This event is triggered after a screen receives focus
event OnReceiveFocus(UIScreen Screen)
{
	local UISquadSelect SquadSelect;
	local XComGameState_SBRSquadManager SquadMgr;
	local XComGameState_SBRSquad CurrentSquad;
	local StateObjectReference SoldierRef;
	local int idx;
	local float currSquadLevel, currSquadAffinity, currSquadEL;
	local string currSquadLevelValText, currSquadAffinityValText, currSquadELValText;
	local UISquadSelect_SquadInfoPanel SquadInfo;

	if(!Screen.IsA('UISquadSelect')) return;

	SquadSelect = UISquadSelect(Screen);
	if(SquadSelect == none) return;

	//`LWTrace("UIScreenListener_SquadSelect_LW: Received focus");
	
	SquadSelect.bDirty = true; // Workaround for bug in currently published version of squad select
	SquadSelect.UpdateData();
	SquadSelect.UpdateNavHelp();


	SquadMgr = class'XComGameState_SBRSquadManager'.static.GetSquadManager();
	CurrentSquad = XComGameState_SBRSquad(`XCOMHISTORY.GetGameStateForObjectID(SquadMgr.LaunchingMissionSquad.ObjectID));

	if (CurrentSquad != none)
	{
		currSquadLevel = CurrentSquad.SquadLevel;
		currSquadLevelValText = class'X2Helper_SquadBasedRoster'.static.TruncFloat(currSquadLevel,1);
		currSquadAffinity = CurrentSquad.GetAverageAffinity(SquadSelect.XComHQ.Squad);
		currSquadAffinityValText = class'X2Helper_SquadBasedRoster'.static.TruncFloat(currSquadAffinity,1);
		
		foreach SquadSelect.XComHQ.Squad(SoldierRef)
		{
			currSquadEL += CurrentSquad.GetEffectiveLevelOnMission(SoldierRef,SquadSelect.XComHQ.Squad );
		}
		currSquadEL = currSquadEL/SquadSelect.XComHQ.Squad.Length;
		currSquadELValText = class'X2Helper_SquadBasedRoster'.static.TruncFloat(currSquadEL,1);


		// Add and update squad info panel
		SquadInfo = UISquadSelect_SquadInfoPanel(SquadSelect.GetChildByName('SquadSelect_SquadInfo', false));
		if (SquadInfo != none)
		{
			`log("UIScreenListener_SquadSelect_LW: Found SquadInfo panel");
			SquadInfo.Remove();
			SquadInfo = SquadSelect.Spawn(class'UISquadSelect_SquadInfoPanel', SquadSelect).InitInfoPanel();
			SquadInfo.MCName = 'SquadSelect_SquadInfo';
			SquadInfo.Update(SquadSelect.XComHQ.Squad, currSquadLevelValText, currSquadAffinityValText,currSquadELValText );
		}
	}






	// Rai - Trigger a check to refresh the status of all squads when a different squad is selected from the drop down list
	//SquadMgr = class'XComGameState_SBRSquadManager'.static.GetSquadManager();
	//SquadMgr.RefreshSquadStatus();

}

// This event is triggered after a screen loses focus
event OnLoseFocus(UIScreen Screen);

// This event is triggered when a screen is removed
event OnRemoved(UIScreen Screen)
{
	local XComGameState_SBRSquadManager SquadMgr;
	local StateObjectReference SquadRef, NullRef;
	local XComGameState_SBRSquad SquadState;
	local XComGameState NewGameState;
	local UISquadSelect SquadSelect;

	if(!Screen.IsA('UISquadSelect')) return;

	SquadSelect = UISquadSelect(Screen);

	//need to move camera back to the hangar, if was in SquadManagement
	if(bInSquadEdit)
	{
		`HQPRES.CAMLookAtRoom(`XCOMHQ.GetFacilityByName('Hangar').GetRoom(), `HQINTERPTIME);
	}

	SquadMgr = class'XComGameState_SBRSquadManager'.static.GetSquadManager();
	SquadRef = SquadMgr.LaunchingMissionSquad;
	SquadRef = SquadMgr.LastMissionSquad;
	if (SquadRef.ObjectID != 0)
	{
		SquadState = XComGameState_SBRSquad(`XCOMHISTORY.GetGameStateForObjectID(SquadRef.ObjectID));
		if (SquadState != none)
		{
			if (SquadState.bTemporary && !SquadSelect.bLaunched)//!!!!!!!!!!
			{
				SquadMgr.RemoveSquadByRef(SquadRef);
				NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Clearing LaunchingMissionSquad");
				SquadMgr = XComGameState_SBRSquadManager(NewGameState.CreateStateObject(class'XComGameState_SBRSquadManager', SquadMgr.ObjectID));
				NewGameState.AddStateObject(SquadMgr);
				SquadMgr.LaunchingMissionSquad = NullRef;
				SquadMgr.RefreshSquadStatus();
				`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);
			}
		}
	}

	// We set the squad status correctly here in case bLaunched is true (i.e. CA/Iniltration was launched)
	// Not sure if we need to do the submission of GS here, but just in case
	if (SquadSelect.bLaunched)//!!!!!!!!!!
	{
		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Clearing LaunchingMissionSquad");
		SquadMgr = XComGameState_SBRSquadManager(NewGameState.CreateStateObject(class'XComGameState_SBRSquadManager', SquadMgr.ObjectID));
		NewGameState.AddStateObject(SquadMgr);
		SquadMgr.RefreshSquadStatus();
		`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);
	}


}


defaultproperties
{
	// Leaving this assigned to none will cause every screen to trigger its signals on this class
	ScreenClass = none;
}