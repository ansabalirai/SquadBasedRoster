//---------------------------------------------------------------------------------------
//  FILE:    XComGameState_SBRSquadManager.uc
//  AUTHOR:  Rai
//  PURPOSE: This singleton object manages persistent squad information for all current squads
//---------------------------------------------------------------------------------------
class XComGameState_SBRSquadManager extends XComGameState_BaseObject config(SquadBasedRoster);

var transient StateObjectReference LaunchingMissionSquad;
var StateObjectReference LastMissionSquad; // This is added as a hack due to how CI generates mission after infiltrations

var int MaxSquads; // Maximum number of squads allowed currently -- UNUSED
var array<StateObjectReference> Squads;   //the squads currently defined

var bool bNeedsAttention;

var config int MAX_SQUAD_SIZE;
var config int MAX_FIRST_MISSION_SQUAD_SIZE;

var config float AFFINITY_GAIN_WHEN_ON_MISSION;
var config float AFFINITY_GAIN_WHEN_ON_MISSION_WON;
var config float AFFINITY_GAIN_WHEN_ON_MISSION_WON_FLAWLESS;
var config float AFFINITY_LOSS_WHEN_NOT_ON_MISSION;
var config float AFFINITY_GAIN_BONUS_CLASSLESS;

var config float SQUAD_LEVEL_GAIN_PER_DAY;
var config float SQUAD_LEVEL_GAIN_PER_MISSION;
var config float SQUAD_LEVEL_GAIN_PER_MISSION_WON;
var config int MAX_SQUAD_LEVEL;

var config float SOLDIER_AFFINITY_FACTOR;
var config float AVERAGE_AFFINITY_FACTOR;
var config float SQUAD_LEVEL_FACTOR;
var config int MAX_SOLDIER_EFFECTIVE_LEVEL;
var config int LEADER_EFFECTIVE_LEVEL_BUMP;
var config int FL_EFFECTIVE_LEVEL_BUMP;

// The name of the sub-menu for resistance management
const nmSquadManagementSubMenu = 'SquadManagementMenu';

var localized string LabelBarracks_SquadManagement;
var localized string TooltipBarracks_SquadManagement;

//---------------------------
// INIT ---------------------
//---------------------------

static function CreateSquadManager(optional XComGameState StartState)
{
	local XComGameState_SBRSquadManager SquadMgr;
	local XComGameState NewGameState;

	//first check that there isn't already a singleton instance of the squad manager
	if(GetSquadManager(true) != none)
		return;

	if(StartState != none)
	{
		SquadMgr = XComGameState_SBRSquadManager(StartState.CreateNewStateObject(class'XComGameState_SBRSquadManager'));
	}
	else
	{
		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Creating SBR Squad Manager Singleton");
		SquadMgr = XComGameState_SBRSquadManager(NewGameState.CreateNewStateObject(class'XComGameState_SBRSquadManager'));
	}
	SquadMgr.InitSquadManagerListeners();
}

static function XComGameState_SBRSquadManager GetSquadManager(optional bool AllowNULL = false)
{
	return XComGameState_SBRSquadManager(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_SBRSquadManager', AllowNULL));
}


// add the first mission squad to the StartState
static function CreateFirstMissionSquad(XComGameState StartState)
{
	local XComGameState_SBRSquad NewSquad;
	local XComGameState_SBRSquadManager StartSquadMgr;
	local XComGameState_HeadquartersXCom StartXComHQ;
	local XComGameState_MissionSite StartMission;
	local XComGameState_Unit Soldier;
	local int idx;

	foreach StartState.IterateByClassType(class'XComGameState_SBRSquadManager', StartSquadMgr)
	{
		break;
	}
	foreach StartState.IterateByClassType(class'XComGameState_HeadquartersXCom', StartXComHQ)
	{
		break;
	}
	foreach StartState.IterateByClassType(class'XComGameState_MissionSite', StartMission)
	{
		break;
	}

	if (StartSquadMgr == none || StartXComHQ == none || StartMission == none)
	{
		return;
	}
	StartXComHQ.MissionRef = StartMission.GetReference();

	//create the first mission squad state
	NewSquad = XComGameState_SBRSquad(StartState.CreateNewStateObject(class'XComGameState_SBRSquad'));

	

    // To do: Init squad and add soldiers from XCOM HQ in there
    // Maybe create and pre-assign soldiers in barracks to squads, which requires having an extra faction soldier in the barracks as the leader
    NewSquad.InitSquad(, false);
	NewSquad.SquadSoldiersOnMission = StartXComHQ.Squad;
	NewSquad.SquadSoldiers = StartXComHQ.Squad;
	NewSquad.CurrentMission = StartXComHQ.MissionRef;

	for (idx = 0; idx < StartXComHQ.Squad.Length; idx++)
	{
		Soldier = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(StartXComHQ.Squad[idx].ObjectID));
		if (Soldier.IsResistanceHero())
		{
			NewSquad.Faction = Soldier.FactionRef; // For some reason, the factionref is not assigned yet??
			NewSquad.Leader = Soldier.GetReference();
		}
	}
	
	NewSquad.SetMissionStatus(StartXComHQ.MissionRef);

	// To DO: Update squad level and kills after mission
	// Also, do we need to submit new game state here or not?
	StartSquadMgr.Squads.AddItem(NewSquad.GetReference());
} 


//-------------------------------------
// UI INTERFACE -----------------------
//-------------------------------------

// After beginning a game, set up the squad management interface.
function SetupSquadManagerInterface()
{
    EnableSquadManagementMenu();
}

// Enable the Squad Manager menu
function EnableSquadManagementMenu(optional bool forceAlert = false)
{
    local string AlertIcon;
    local UIAvengerShortcutSubMenuItem SubMenu;
    local UIAvengerShortcuts Shortcuts;

    ShortCuts = `HQPRES.m_kAvengerHUD.Shortcuts;

    if (ShortCuts.FindSubMenu(eUIAvengerShortcutCat_Barracks, nmSquadManagementSubMenu, SubMenu))
    {
        // It already exists: just update the label to adjust the alert state (if necessary).
        SubMenu.Message.Label = AlertIcon $ LabelBarracks_SquadManagement;
        Shortcuts.UpdateSubMenu(eUIAvengerShortcutCat_Barracks, SubMenu);
    }
    else
    {
        SubMenu.Id = nmSquadManagementSubMenu;
        SubMenu.Message.Label = AlertIcon $ LabelBarracks_SquadManagement;
        SubMenu.Message.Description = TooltipBarracks_SquadManagement;
        SubMenu.Message.Urgency = eUIAvengerShortcutMsgUrgency_Low;
        SubMenu.Message.OnItemClicked = GoToSquadManagement;
        Shortcuts.AddSubMenu(eUIAvengerShortcutCat_Barracks, SubMenu);
    }
}

simulated function GoToSquadManagement(optional StateObjectReference Facility)
{
    local XComHQPresentationLayer HQPres;
    local UIAvengerShortcutSubMenuItem SubMenu;
    local UIAvengerShortcuts Shortcuts;
	local UIPersonnel_SquadBarracks kPersonnelList;

    HQPres = `HQPRES;

    ShortCuts = HQPres.m_kAvengerHUD.Shortcuts;
    Shortcuts.FindSubMenu(eUIAvengerShortcutCat_Barracks, nmSquadManagementSubMenu, SubMenu);
    SubMenu.Message.Label = LabelBarracks_SquadManagement;
    Shortcuts.UpdateSubMenu(eUIAvengerShortcutCat_Barracks, SubMenu);

	
	if (HQPres.ScreenStack.IsNotInStack(class'UIPersonnel_SquadBarracks'))
	{
		kPersonnelList = HQPres.Spawn(class'UIPersonnel_SquadBarracks', HQPres);
		//kPersonnelList.onSelectedDelegate = OnPersonnelSelected;
		HQPres.ScreenStack.Push(kPersonnelList);
	}
}

/* function SetSquadMgrNeedsAttention(bool Enable)
{
    local XComGameState NewGameState;
    local XComGameState_FacilityXCom BarracksFacility;
    local XComGameState_SBRSquadManager NewManager;
    
    if (Enable != NeedsAttention())
    {
        // Set the rebel outpost manager as needing attention (or not)
        NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Set squad manager needs attention");
        NewManager = XComGameState_SBRSquadManager(NewGameState.CreateStateObject(class'XComGameState_SBRSquadManager', self.ObjectID));
        NewGameState.AddStateObject(NewManager);
        if (Enable)
        {
            NewManager.SetNeedsAttention();
        }
        else
        {
            NewManager.ClearNeedsAttention();
        }

        // And update the CIC state to also require attention if necessary.
        // We don't need to clear it as clearing happens automatically when the 
        // facility is selected.
        BarracksFacility = `XCOMHQ.GetFacilityByName('Hangar');
        if (Enable && !BarracksFacility.NeedsAttention())
        {
            BarracksFacility = XComGameState_FacilityXCom(NewGameState.CreateStateObject(class'XComGameState_FacilityXCom', BarracksFacility.ObjectID));
            BarracksFacility.TriggerNeedsAttention();
            NewGameState.AddStateObject(BarracksFacility);
        }

        `XCOMGAME.GameRuleset.SubmitGameState(NewGameState);
    }
} */

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


//-------------------------------------
// GETTERS ---------------------
//-------------------------------------
function int NumSquadsOnAnyMission()
{
	local XComGameState_SBRSquad Squad;
	local int idx;
	local int NumMissions;

	for (idx = 0; idx < Squads.Length; idx++)
	{
		Squad = GetSquad(idx);
		if (Squad.bOnMission && Squad.CurrentMission.ObjectID > 0) //This probably does not work
			NumMissions++;
	}
	return NumMissions;
}

//gets the squad assigned to a given mission -- may be none if mission is not being pursued
function XComGameState_SBRSquad GetSquadOnMission(StateObjectReference MissionRef)
{
	local XComGameState_SBRSquad Squad;
	local int idx;
	local XComGameStateHistory History;

	if(MissionRef.ObjectID == 0) return none;

	History = `XCOMHISTORY;
	for(idx = 0; idx < Squads.Length; idx++)
	{
		Squad = XComGameState_SBRSquad(History.GetGameStateForObjectID(Squads[idx].ObjectID));
		if(Squad != none && Squad.CurrentMission.ObjectID == MissionRef.ObjectID) //THis probably does not work
			return Squad;
	}
	return none;
}

// Rai - Cheat to assign returning squad and mission ref to the most recent squad in LaunchingMissionSquad...
// This currently only works for gatecrahser
// To DO - OnPreMission, compare the XCOMHQ.Squad to the deployed squads to find out which squad is on this mission and set their status accordingly
function XComGameState_SBRSquad GetSquadAfterMission(StateObjectReference MissionRef)
{
	local XComGameState_SBRSquad Squad;
	local int idx;
	local XComGameStateHistory History;

	if(MissionRef.ObjectID == 0) return none;

	// Squad = XComGameState_SBRSquad(`XCOMHISTORY.GetGameStateForObjectID(LastMissionSquad.ObjectID));
	// if(Squad != none) 
	// 	{
	// 		Squad.SquadSoldiersOnMission = `XCOMHQ.Squad;
	// 		Squad.SetMissionStatus(`XCOMHQ.MissionRef);
	// 		`LOG("SBR: Cheat to assign returning squad and mission ref to the most recent squad in LaunchingMissionSquad...");
	// 		return Squad;
	// 	}

	History = `XCOMHISTORY;
	for(idx = 0; idx < Squads.Length; idx++)
	{
		Squad = XComGameState_SBRSquad(History.GetGameStateForObjectID(Squads[idx].ObjectID));
		if(Squad != none && Squad.CurrentMission.ObjectID == MissionRef.ObjectID)
			return Squad;
	}
	return none;
}

// More like get random squad
function StateObjectReference GetBestSquad()
{
	local array<XComGameState_SBRSquad> PossibleSquads;
	local XComGameState_SBRSquad Squad;
	local int idx;
	local StateObjectReference NullRef;

	for (idx = 0; idx < Squads.Length; idx++)
	{
		Squad = GetSquad(idx);
		if (!Squad.bOnMission && Squad.CurrentMission.ObjectID == 0)
		{
			PossibleSquads.AddItem(Squad);
		} 
	}

	if (PossibleSquads.Length > 0)
		return PossibleSquads[`SYNC_RAND(PossibleSquads.Length)].GetReference();
	else
		return NullRef;
}

function XComGameState_SBRSquad GetSquad(int idx)
{
	if(idx >=0 && idx < Squads.Length)
	{
		return XComGameState_SBRSquad(`XCOMHISTORY.GetGameStateForObjectID(Squads[idx].ObjectID));
	}
	return none;
} 

function XComGameState_SBRSquad GetSquadByName(string SquadName)
{
	local XComGameState_SBRSquad Squad;
	local int idx;
	local XComGameStateHistory History;

	History = `XCOMHISTORY;
	for(idx = 0; idx < Squads.Length; idx++)
	{
		Squad = XComGameState_SBRSquad(History.GetGameStateForObjectID(Squads[idx].ObjectID));
		if(Squad.SquadName == SquadName)
			return Squad;
	}
	return none;
}

// Return list of references to all soldiers assigned to any squad
function array<StateObjectReference> GetAssignedSoldiers()
{
	local array<StateObjectReference> UnitRefs;
	local XComGameState_SBRSquad Squad;
	local int SquadIdx, UnitIdx;

	for(SquadIdx = 0; SquadIdx < Squads.Length; SquadIdx++)
	{
		Squad = GetSquad(SquadIdx);
		for(UnitIdx = 0; UnitIdx < Squad.SquadSoldiers.Length; UnitIdx++)
		{
			UnitRefs.AddItem(Squad.SquadSoldiers[UnitIdx]);
		}
		for(UnitIdx = 0; UnitIdx < Squad.SquadSoldiersOnMission.Length; UnitIdx++)
		{
			if (UnitRefs.Find('ObjectID', Squad.SquadSoldiersOnMission[UnitIdx].ObjectID) == -1)
				UnitRefs.AddItem(Squad.SquadSoldiersOnMission[UnitIdx]);
		}
	}
	return UnitRefs;
}

// Return list of references to all soldier NOT assigned to any squad
function array<StateObjectReference> GetUnassignedSoldiers()
{
	local XComGameState_HeadquartersXCom HQState;
	local array<StateObjectReference> AssignedRefs, UnassignedRefs;
	local array<XComGameState_Unit> Soldiers;
	local XComGameState_Unit Soldier;

	HQState = `XCOMHQ;
	Soldiers = HQState.GetSoldiers();
	AssignedRefs = GetAssignedSoldiers();
	foreach Soldiers(Soldier)
	{
		if(AssignedRefs.Find('ObjectID', Soldier.ObjectID) == -1)
		{
			UnassignedRefs.AddItem(Soldier.GetReference());
		}
	}
	return UnassignedRefs;
}

function bool UnitIsInAnySquad(StateObjectReference UnitRef, optional out XComGameState_SBRSquad SquadState)
{
	local int idx;

	for(idx = 0; idx < Squads.Length; idx++)
	{
		SquadState = GetSquad(idx);
		if(SquadState.UnitIsInSquad(UnitRef))
			return true;
	}
	SquadState = none;
	return false;
}

function bool UnitIsOnMission(StateObjectReference UnitRef, optional out XComGameState_SBRSquad SquadState)
{
	local int idx;

	for(idx = 0; idx < Squads.Length; idx++)
	{
		SquadState = GetSquad(idx);
		if(SquadState.UnitIsInSquadOnMission(UnitRef))
			return true;
	}
	SquadState = none;
	return false;
}

// Rai - This is defined to refresh the on mission status for all squads
// To DO: Find a better way to do this
function RefreshSquadStatus()
{
	local XComGameState_SBRSquad SquadState;
	local int idx;

	for(idx = 0; idx < Squads.Length; idx++)
	{
		SquadState = GetSquad(idx);
		SquadState.IsDeployedOnMission();
		if (SquadState.bOnMission)
			`Log("RefreshSquadStatus: " $ SquadState.SquadName $ " Status is On Mission" );
		else
			`Log("RefreshSquadStatus: " $ SquadState.SquadName $ " Status is Available" );
	}

	// Also updating the squad levels here as well
	UpdateSquadLevelsAfterMission();
}


//-------------------------------------
// SQUAD ADD/REMOVE---------------------
//-------------------------------------

//creates an empty squad at the given position with the given name
function XComGameState_SBRSquad CreateEmptySquad(optional int idx = -1, optional string SquadName = "", optional XComGameState NewGameState, optional bool bTemporary)
{
	//local XComGameStateHistory History;
	//local XComGameState NewGameState;
	local XComGameState_SBRSquad NewSquad;
	local XComGameState_SBRSquadManager UpdatedSquadMgr;
	local bool bNeedsUpdate;

	//History = `XCOMHISTORY;
	bNeedsUpdate = NewGameState == none;
	if (bNeedsUpdate)
		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Adding new empty squad");

	NewSquad = XComGameState_SBRSquad(NewGameState.CreateStateObject(class'XComGameState_SBRSquad'));
	UpdatedSquadMgr = XComGameState_SBRSquadManager(NewGameState.CreateStateObject(Class, ObjectID));

	NewSquad.InitSquad(SquadName, bTemporary);
	if(idx <= 0 || idx >= Squads.Length)
		UpdatedSquadMgr.Squads.AddItem(NewSquad.GetReference());
	else
		UpdatedSquadMgr.Squads.InsertItem(idx, NewSquad.GetReference());

	NewGameState.AddStateObject(NewSquad);
	NewGameState.AddStateObject(UpdatedSquadMgr);
	if (bNeedsUpdate)
		`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);

	return NewSquad;
}


function XComGameState_SBRSquad AddSquad(optional array<StateObjectReference> Soldiers, optional StateObjectReference MissionRef, optional string SquadName="", optional bool Temp = true, optional float Infiltration=0)
{
	local XComGameState NewGameState;
	local XComGameState_SBRSquad NewSquad;
	local XComGameState_SBRSquadManager UpdatedSquadMgr;

	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Adding new SBR squad");
	NewSquad = XComGameState_SBRSquad(NewGameState.CreateStateObject(class'XComGameState_SBRSquad'));
	UpdatedSquadMgr = XComGameState_SBRSquadManager(NewGameState.CreateStateObject(Class, ObjectID));

	NewSquad.InitSquad(SquadName, Temp);
	UpdatedSquadMgr.Squads.AddItem(NewSquad.GetReference());

	if(MissionRef.ObjectID > 0)
		NewSquad.SquadSoldiersOnMission = Soldiers;
	else
		NewSquad.SquadSoldiers = Soldiers;

	//NewSquad.InitInfiltration(NewGameState, MissionRef, Infiltration);
	NewSquad.SetOnMissionSquadSoldierStatus(NewGameState);
	NewSquad.SetMissionStatus(MissionRef);
	NewGameState.AddStateObject(NewSquad);
	NewGameState.AddStateObject(UpdatedSquadMgr);
	`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);

	return NewSquad;
}


function RemoveSquad_Internal(int idx, XComGameState NewGameState)
{
	local XComGameState_SBRSquadManager UpdatedSquadMgr;
	local XComGameState_SBRSquad SquadState;

	UpdatedSquadMgr = XComGameState_SBRSquadManager(NewGameState.CreateStateObject(Class, ObjectID));
	NewGameState.AddStateObject(UpdatedSquadMgr);
	if(idx >= 0 && idx < UpdatedSquadMgr.Squads.Length )
	{
		UpdatedSquadMgr.Squads.Remove(idx, 1);
	}

	SquadState = GetSquad(idx);
	NewGameState.RemoveStateObject(SquadState.ObjectID);
}

function RemoveSquad(int idx)
{
	local XComGameState NewGameState;

	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Removing Squad");
	RemoveSquad_Internal(idx, NewGameState);
	`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);
}

function RemoveSquadByRef(StateObjectReference SquadRef)
{
	local int idx;

	idx = Squads.Find('ObjectID', SquadRef.ObjectID);
	if(idx != -1)
		RemoveSquad(idx);
}

//-------------------------------------
// SQUAD UPDATES ---------------------
//-------------------------------------

// To DO - OnPreMission, compare the XCOMHQ.Squad to the deployed squads to find out which squad is on this mission and set their status accordingly
function UpdateSquadPreMission()
{
	//local XComGameStateHistory History;
	local XComGameState_HeadquartersXCom XComHQ;
	local XComGameStateHistory History;
	local XComGameState_SBRSquad SquadState, UpdatedSquadState;
	local XComGameState NewGameState;
	local XComGameState_SBRSquadManager UpdatedSquadMgr;
	local XComGameState_MissionSite MissionSite;
	local StateObjectReference MissionRef, NullRef;
	local array<StateObjectReference> DeployedSoldierOnMissionRef, SquadSoldiersRef, DeployedSoldierOnMissionRef2;
	local int idx, jdx, kdx, SoldiersOnMission, maxMatch, maxMatchId;
	local array<int> matches;

	History = `XCOMHISTORY;
	XComHQ = `XCOMHQ;

	// Assume that the missionRef is correct
	MissionRef = XComHQ.MissionRef;

	DeployedSoldierOnMissionRef = XComHQ.Squad;
	SoldiersOnMission = DeployedSoldierOnMissionRef.Length;
	// This is needed since it is possible to have less than the max number of soliders deployed
	for (idx = 0; idx < SoldiersOnMission; idx++)
	{
		if (DeployedSoldierOnMissionRef[idx].ObjectID != 0 )
			DeployedSoldierOnMissionRef2.AddItem(DeployedSoldierOnMissionRef[idx]);
	}
	// Iterate over all current squads and compare to the XCOMHQ.Squad soldiers to find out which one is deployed
	// If we cannot match ?
	for (idx = 0; idx < Squads.Length; idx++)
	{
		//SquadState = GetSquad(idx);
		//if (!SquadState.bOnMission) //This can be set if squad leader is already deployed, in which case, we do not count this mission as "done" for this squad
		// 	continue;				// This squad is not the one infiltrating

		SquadState = XComGameState_SBRSquad(History.GetGameStateForObjectID(Squads[idx].ObjectID));
		
		SquadSoldiersRef = SquadState.GetSoldierRefs(true);

		matches.AddItem(0);
		for (jdx = 0; jdx < DeployedSoldierOnMissionRef2.Length; jdx++)
		{
			for (kdx = 0; kdx < SquadSoldiersRef.Length; kdx++)
			{
				if (DeployedSoldierOnMissionRef2[jdx].ObjectID == SquadSoldiersRef[kdx].ObjectID)
					matches[idx]++;

			}
		}
	}
	
	// Find max matched squad
	maxMatch = 0;
	for (idx = 0; idx < matches.Length; idx++)
	{
		if (matches[idx] > maxMatch)
		{
			maxMatch = matches[idx];
			maxMatchId = idx;
		}
	}

	// Build NewGameState change container
	// NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Update Squad MissionRef pre-mission");
	// UpdatedSquadMgr = XComGameState_SBRSquadManager(NewGameState.CreateStateObject(class'XComGameState_SBRSquadManager', UpdatedSquadMgr.ObjectID));
	// NewGameState.AddStateObject(UpdatedSquadMgr);

	`Log("SquadBasedRoster: Setting mission status for Squad " $ GetSquad(maxMatchId).SquadName $ " with soldiers on mission: "	$ maxMatch);
	//SquadState = XComGameState_SBRSquad(History.GetGameStateForObjectID(Squads[maxMatchId].ObjectID));
	GetSquad(maxMatchId).SetMissionStatus(MissionRef);


	// if (NewGameState.GetNumGameStateObjects() > 0)
	// {
	// 	`GAMERULES.SubmitGameState(NewGameState);
	// }
	// else
	// {
	// 	History.CleanupPendingGameState(NewGameState);
	// }
	

}

function UpdateSquadPostMission(optional StateObjectReference MissionRef, optional bool bCompletedMission)
{
	//local XComGameStateHistory History;
	local XComGameState_HeadquartersXCom XComHQ;
	local XComGameState_SBRSquad SquadState, UpdatedSquadState;
	local XComGameState UpdateState;
	local XComGameState_SBRSquadManager UpdatedSquadMgr;
	local XComGameState_MissionSite MissionSite;
	local StateObjectReference NullRef;

	//History = `XCOMHISTORY;
	if (MissionRef.ObjectID == 0)
	{
		XComHQ = `XCOMHQ;
		MissionRef = XComHQ.MissionRef;
	}

	// Get the mission info
	MissionSite = XComGameState_MissionSite(`XCOMHISTORY.GetGameStateForObjectID(MissionRef.ObjectID));

	// CI Gatecrasher check
	//MissionSite.GeneratedMission.Mission.sType = "GatecrasherCI";

	SquadState = GetSquadAfterMission(MissionRef);
	if(SquadState == none)
	{
		`REDSCREEN("SquadManager : UpdateSquadPostMission called with no squad on mission");
		return;
	}
	UpdateState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Post Mission Persistent Squad Cleanup");

	UpdatedSquadMgr = XComGameState_SBRSquadManager(UpdateState.CreateStateObject(Class, ObjectID));
	UpdateState.AddStateObject(UpdatedSquadMgr);

	UpdatedSquadState = XComGameState_SBRSquad(UpdateState.CreateStateObject(SquadState.Class, SquadState.ObjectID));
	UpdateState.AddStateObject(UpdatedSquadState);

	UpdatedSquadState.NumMissions += 1;
	if (bCompletedMission)
		UpdatedSquadState.NumMissionsSuccessful +=1;
		

	UpdatedSquadMgr.LaunchingMissionSquad = NullRef;
	UpdatedSquadState.PostMissionRevertSoldierStatus(UpdateState, UpdatedSquadMgr);
	UpdatedSquadState.ClearMission();
	UpdatedSquadState.IsDeployedOnMission(); // Running this function to update the status of the squad in case some soldiers are on covert action
	RefreshSquadStatus(); // Not sure if we need to do this...
	

	if(SquadState.bTemporary)
	{
		RemoveSquadByRef(SquadState.GetReference());
	}

	`XCOMGAME.GameRuleset.SubmitGameState(UpdateState);
}

//-------------------------------------
// SQUAD LEVEL/AFFINITY UPDATES -------
//-------------------------------------
// THis updates the squad levels for all squads
function UpdateSquadLevelsAfterMission()
{
	local XComGameState_SBRSquad SquadState;
	local XComGameState_BattleData BattleState;
	local int idx, DaysSinceCreation, CurrentForceLevel;
	local TDateTime CurrentTime;
	local float FromTimeElapsed, OldSquadLevel, SquadLevelMin;


	CurrentForceLevel = class'UIUtilities_Strategy'.static.GetAlienHQ().ForceLevel;
	SquadLevelMin = Max (0,CurrentForceLevel - 4);

	if (`GAME.GetGeoscape().m_kDateTime.m_iYear != 0 )
		CurrentTime = `GAME.GetGeoscape().m_kDateTime;
	else
	{	
		BattleState = XComGameState_BattleData(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_BattleData'));
		CurrentTime = BattleState.LocalTime;
	}

	for (idx = 0; idx < Squads.Length; idx++)
	{
		SquadState = GetSquad(idx);
		DaysSinceCreation = class'X2StrategyGameRulesetDataStructures'.static.DifferenceInDays(SquadState.SquadCreationTime, CurrentTime);
		DaysSinceCreation = Min(Max(0,DaysSinceCreation),9999);

		OldSquadLevel = SquadState.SquadLevel;

		SquadState.SquadLevel = default.SQUAD_LEVEL_GAIN_PER_DAY * DaysSinceCreation;
		SquadState.SquadLevel += SquadState.NumMissions * default.SQUAD_LEVEL_GAIN_PER_MISSION;
		SquadState.SquadLevel += SquadState.NumMissionsSuccessful * default.SQUAD_LEVEL_GAIN_PER_MISSION_WON;

/* 		if (OnMissionSquad.ObjectID == SquadState.ObjectID)
		{
			SquadState.SquadLevel += SquadState.NumMissions * default.SQUAD_LEVEL_GAIN_PER_MISSION;
			if (bMissionWon)
				SquadState.SquadLevel += SquadState.NumMissionsSuccessful * default.SQUAD_LEVEL_GAIN_PER_MISSION_WON;
		} */

		// To do: Some clamping for min/max levels based on FL etc
		// Currently just clamping between 0 and max?
		SquadState.SquadLevel = Max(SquadState.SquadLevel, SquadLevelMin);
		SquadState.SquadLevel = Min(SquadState.SquadLevel, default.MAX_SQUAD_LEVEL);

		// Some caching
		SquadState.SquadLevel = Max (SquadState.SquadLevel, OldSquadLevel);

	}
}





//-------------------------------------
// EVENT HANDLERS ---------------------
//-------------------------------------
function InitSquadManagerListeners()
{
	local X2EventManager EventMgr;
	local Object ThisObj;

	ThisObj = self;
	EventMgr = `XEVENTMGR;
	EventMgr.UnregisterFromAllEvents(ThisObj); // clear all old listeners to clear out old stuff before re-registering

	EventMgr.RegisterForEvent(ThisObj, 'OnValidateDeployableSoldiers', ValidateDeployableSoldiersForSquads,,,,true);
	EventMgr.RegisterForEvent(ThisObj, 'OnSoldierListItemUpdateDisabled', SetDisabledSquadListItems,,,,true);  // hook to disable selecting soldiers if they are in another squad
	EventMgr.RegisterForEvent(ThisObj, 'OnUpdateSquadSelectSoldiers', ConfigureSquadOnEnterSquadSelect, ELD_Immediate,,,true); // hook to set initial squad/soldiers on entering squad select
	EventMgr.RegisterForEvent(ThisObj, 'OnDismissSoldier', DismissSoldierFromSquad, ELD_Immediate,,,true); // allow clearing of units from existing squads when dismissed
	// Registering event to update affinities for units on the mission for all squads
	EventMgr.RegisterForEvent(ThisObj, 'OnDistributeTacticalGameEndXP', UpdateSquadAffinities, ELD_OnStateSubmitted,,,true);
	
	//EventMgr.RegisterForEvent(ThisObj, 'SoldierRankIcon', OverrideSpecialistRankIcon, ELD_Immediate,,,true);

	`LOG("SquadBasedRoster: Squad Manager Events Registered");

}

function EventListenerReturn ValidateDeployableSoldiersForSquads(Object EventData, Object EventSource, XComGameState NewGameState, Name InEventID, Object CallbackData)
{
	local int idx;
	local XComLWTuple DeployableSoldiers;
	local UISquadSelect SquadSelect;
	local XComGameState_Unit UnitState;
	local XComGameState_SBRSquad CurrentSquad, TestUnitSquad;

	DeployableSoldiers = XComLWTuple(EventData);
	if(DeployableSoldiers == none)
	{
		`REDSCREEN("Validate Deployable Soldiers event triggered with invalid event data.");
		return ELR_NoInterrupt;
	}
	SquadSelect = UISquadSelect(EventSource);
	if(SquadSelect == none)
	{
		`REDSCREEN("Validate Deployable Soldiers event triggered with invalid source data.");
		return ELR_NoInterrupt;
	}

	if(DeployableSoldiers.Id != 'DeployableSoldiers')
		return ELR_NoInterrupt;

	if(LaunchingMissionSquad.ObjectID > 0)
	{
		CurrentSquad = XComGameState_SBRSquad(`XCOMHISTORY.GetGameStateForObjectID(LaunchingMissionSquad.ObjectID));
	}
	for(idx = DeployableSoldiers.Data.Length - 1; idx >= 0; idx--)
	{
		if(DeployableSoldiers.Data[idx].kind == XComLWTVObject)
		{
			UnitState = XComGameState_Unit(DeployableSoldiers.Data[idx].o);
			if(UnitState != none)
			{
				//disallow if unit is in a different squad
				if (UnitIsInAnySquad(UnitState.GetReference(), TestUnitSquad))
				{
					if (TestUnitSquad != none && TestUnitSquad.ObjectID != CurrentSquad.ObjectID)
					{
						DeployableSoldiers.Data.Remove(idx, 1);
					}
				}
			}
		}
	}
	return ELR_NoInterrupt;
}

function EventListenerReturn SetDisabledSquadListItems(Object EventData, Object EventSource, XComGameState NewGameState, Name InEventID, Object CallbackData)
{
	local UIPersonnel_ListItem ListItem;
	local XComGameState_SBRSquad Squad;
    local XComGameState_Unit UnitState;
	local bool								bInSquadEdit;

	//only do this for squadselect
	if(GetSquadSelect() == none)
		return ELR_NoInterrupt;

	ListItem = UIPersonnel_ListItem(EventData);
	if(ListItem == none)
	{
		`REDSCREEN("Set Disabled Squad List Items event triggered with invalid event data.");
		return ELR_NoInterrupt;
	}

	bInSquadEdit = `SCREENSTACK.IsInStack(class'UIPersonnel_SquadBarracks');

	if(ListItem.UnitRef.ObjectID > 0)
	{
		if (LaunchingMissionSquad.ObjectID > 0)
			Squad = XComGameState_SBRSquad(`XCOMHISTORY.GetGameStateForObjectID(LaunchingMissionSquad.ObjectID));

        UnitState = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(ListItem.UnitRef.ObjectID));
		if(bInSquadEdit && UnitIsInAnySquad(ListItem.UnitRef) && (Squad == none || !Squad.UnitIsInSquad(ListItem.UnitRef)))
		{
			ListItem.SetDisabled(true); // can now select soldiers from other squads, but will generate pop-up warning and remove them
		}
        // else 
		// if (class'LWDLCHelpers'.static.IsUnitOnMission(UnitState))
        // {
		//     ListItem.SetDisabled(true);
		// }
            
	}
	return ELR_NoInterrupt;
}

//selects a squad that matches a persistent squad 
function EventListenerReturn ConfigureSquadOnEnterSquadSelect(Object EventData, Object EventSource, XComGameState NewGameState, Name InEventID, Object CallbackData)
{
	local XComGameStateHistory				History;
	local XComGameState_HeadquartersXCom	XComHQ, UpdatedXComHQ;
	local UISquadSelect						SquadSelect;
	local XComGameState_SBRSquadManager		UpdatedSquadMgr;
	local StateObjectReference				SquadRef;
	local XComGameState_SBRSquad	SquadState;
	local bool								bInSquadEdit;
	local XComGameState_MissionSite			MissionSite;
	local GeneratedMissionData				MissionData;
	local int								MaxSoldiersInSquad;

	//`LWTRACE("ConfigureSquadOnEnterSquadSelect : Starting listener.");
	XComHQ = XComGameState_HeadquartersXCom(EventData);
	if(XComHQ == none)
	{
		`REDSCREEN("OnUpdateSquadSelectSoldiers event triggered with invalid event data.");
		return ELR_NoInterrupt;
	}
	//`LWTRACE("ConfigureSquadOnEnterSquadSelect : Parsed XComHQ.");

	SquadSelect = GetSquadSelect();
	if(SquadSelect == none)
	{
		`REDSCREEN("ConfigureSquadOnEnterSquadSelect event triggered with UISquadSelect not in screenstack.");
		return ELR_NoInterrupt;
	}
	//`LWTRACE("ConfigureSquadOnEnterSquadSelect : RetrievedSquadSelect.");

	History = `XCOMHISTORY;

	bInSquadEdit = `SCREENSTACK.IsInStack(class'UIPersonnel_SquadBarracks');
	if (bInSquadEdit)
		return ELR_NoInterrupt;

	MissionSite = XComGameState_MissionSite(History.GetGameStateForObjectID(XComHQ.MissionRef.ObjectID));
	MissionData = MissionSite.GeneratedMission;

	if (LaunchingMissionSquad.ObjectID > 0)
	{
		SquadRef = LaunchingMissionSquad;
	}
		
	else	
		SquadRef = GetBestSquad();

	UpdatedSquadMgr = XComGameState_SBRSquadManager(NewGameState.ModifyStateObject(Class, ObjectID));

	if(SquadRef.ObjectID > 0)
		SquadState = XComGameState_SBRSquad(History.GetGameStateForObjectID(SquadRef.ObjectID));
	else
		SquadState = UpdatedSquadMgr.CreateEmptySquad(,, NewGamestate, true);  // create new, empty, temporary squad

	UpdatedSquadMgr.LaunchingMissionSquad = SquadState.GetReference();
	UpdatedSquadMgr.LastMissionSquad = SquadState.GetReference();

	UpdatedXComHQ = XComGameState_HeadquartersXCom(NewGameState.ModifyStateObject(XComHQ.Class, XComHQ.ObjectID));
	UpdatedXComHQ.Squad = SquadState.GetDeployableSoldierRefs(MissionData.Mission.AllowDeployWoundedUnits); 

	MaxSoldiersInSquad = class'X2StrategyGameRulesetDataStructures'.static.GetMaxSoldiersAllowedOnMission(MissionSite);
	if (UpdatedXComHQ.Squad.Length > MaxSoldiersInSquad)
		UpdatedXComHQ.Squad.Length = MaxSoldiersInSquad;

	//if (NewGameState.GetNumGameStateObjects() > 0)
		//`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);
	//else
		//History.CleanupPendingGameState(NewGameState);

	return ELR_NoInterrupt;
}

function EventListenerReturn DismissSoldierFromSquad(Object EventData, Object EventSource, XComGameState GameState, Name InEventID, Object CallbackData)
{
	local XComGameState_Unit DismissedUnit;
	local UIArmory_MainMenu MainMenu;
	local StateObjectReference DismissedUnitRef;
	local XComGameState_SBRSquad SquadState, UpdatedSquadState;
	local XComGameState NewGameState;
	local int idx;

	DismissedUnit = XComGameState_Unit(EventData);
	if(DismissedUnit == none)
	{
		`REDSCREEN("Dismiss Soldier From Squad listener triggered with invalid event data.");
		return ELR_NoInterrupt;
	}
	MainMenu = UIArmory_MainMenu(EventSource);
	if(MainMenu == none)
	{
		`REDSCREEN("Dismiss Soldier From Squad listener triggered with invalid source data.");
		return ELR_NoInterrupt;
	}

	DismissedUnitRef = DismissedUnit.GetReference();

	for(idx = 0; idx < Squads.Length; idx++)
	{
		SquadState = GetSquad(idx);
		if(SquadState.UnitIsInSquad(DismissedUnitRef))
		{
			NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Removing Dismissed Soldier from Squad");
			UpdatedSquadState = XComGameState_SBRSquad(NewGameState.CreateStateObject(class'XComGameState_SBRSquad', SquadState.ObjectID));
			NewGameState.AddStateObject(UpdatedSquadState);
			UpdatedSquadState.RemoveSoldier(DismissedUnitRef);
			`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);
		}
	}

	return ELR_NoInterrupt;
}

function EventListenerReturn UpdateSquadAffinities(Object EventData, Object EventSource, XComGameState GameState, Name InEventID, Object CallbackData)
{
	local bool PlayerWonMission, bFlawless;
	local XComGameState NewGameState;
	local XComGameState_HeadquartersXCom XComHQ;
	local XComGameStateHistory History;
	local XComGameState_BattleData BattleState;
	local XComGameState_MissionSite MissionState;
	local X2MissionSourceTemplate MissionSource;
	local XComGameState_SBRSquadManager SquadManager;
	local XComGameState_SBRSquad OnMissionSquad;
	local XComGameState_Unit Soldier;
	local StateObjectReference UnitRef, CommandingRef;
	local array<StateObjectReference> AllSoldierRefsNotOnMission;
	local int idx;



	XComHQ = XComGameState_HeadquartersXCom(EventData);
	if (XComHQ == none)
	{
		return ELR_NoInterrupt;
	}

	History = `XCOMHISTORY;

	// Determine if strategy objectives were met
	BattleState = XComGameState_BattleData(History.GetSingleGameStateObjectForClass(class'XComGameState_BattleData'));
	if ((BattleState != none) && (BattleState.m_iMissionID != XComHQ.MissionRef.ObjectID))
	{
		`REDSCREEN("Mismatch in BattleState and XComHQ MissionRef when updating Squad Affinity Data");
		return ELR_NoInterrupt;
	}

	MissionState = XComGameState_MissionSite(History.GetGameStateForObjectID(BattleState.m_iMissionID));
	if (MissionState == none) // See if we can skip ambush missions
	{
		return ELR_NoInterrupt;
	}

	PlayerWonMission = true;
	bFlawless = true;
	MissionSource = MissionState.GetMissionSource();
	if (MissionSource.WasMissionSuccessfulFn != none)
	{
		PlayerWonMission = MissionSource.WasMissionSuccessfulFn(BattleState);
	}

	// // Build NewGameState change container
	// NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Update Squad Affinity Data post-mission");
	// SquadManager = XComGameState_SBRSquadManager(NewGameState.CreateStateObject(class'XComGameState_SBRSquadManager', SquadManager.ObjectID));
	// NewGameState.AddStateObject(SquadManager);


	// Find out which squad was on this mission from history
	OnMissionSquad = GetSquadAfterMission(MissionState.GetReference());
	if (OnMissionSquad == none)
	{
		return ELR_NoInterrupt;
	}

	AllSoldierRefsNotOnMission = class'X2Helper_SquadBasedRoster'.static.GetAllSoldierRefsNotOnMission();
	

	// First remove affinity for soldiers not on mission for THIS squad
	// May need additional handling here for leaders/specialists
	foreach AllSoldierRefsNotOnMission(UnitRef)
	{
		OnMissionSquad.UpdateAffinity(UnitRef, default.AFFINITY_LOSS_WHEN_NOT_ON_MISSION);
	}

	// Add affinity for soldies on mission for THIS squad
	foreach XComHQ.Squad(UnitRef)
	{
		Soldier = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(UnitRef.ObjectID));
		if (Soldier.GetMyTemplateName() != 'SparkSoldier' && (Soldier.WasInjuredOnMission() || Soldier.IsDead( ) || Soldier.IsBleedingOut())) //Need a better check here :(
			bFlawless = false;
	}

	foreach XComHQ.Squad(UnitRef)
	{
		if (class'X2DownloadableContentInfo_SquadBasedRoster'.default.GO_CLASSLESS)
		{
			if (PlayerWonMission && bFlawless)
			{
				OnMissionSquad.UpdateAffinity(UnitRef,  (default.AFFINITY_GAIN_WHEN_ON_MISSION + default.AFFINITY_GAIN_WHEN_ON_MISSION_WON + default.AFFINITY_GAIN_WHEN_ON_MISSION_WON_FLAWLESS + default.AFFINITY_GAIN_BONUS_CLASSLESS));
			}
			else if (PlayerWonMission)
			{
				OnMissionSquad.UpdateAffinity(UnitRef,  (default.AFFINITY_GAIN_WHEN_ON_MISSION + default.AFFINITY_GAIN_WHEN_ON_MISSION_WON + default.AFFINITY_GAIN_BONUS_CLASSLESS));
			}
			else
			{
				OnMissionSquad.UpdateAffinity(UnitRef,  (default.AFFINITY_GAIN_WHEN_ON_MISSION + default.AFFINITY_GAIN_BONUS_CLASSLESS));
			}
		}

		else
		{
			if (PlayerWonMission && bFlawless)
			{
				OnMissionSquad.UpdateAffinity(UnitRef,  (default.AFFINITY_GAIN_WHEN_ON_MISSION + default.AFFINITY_GAIN_WHEN_ON_MISSION_WON + default.AFFINITY_GAIN_WHEN_ON_MISSION_WON_FLAWLESS));
			}
			else if (PlayerWonMission)
			{
				OnMissionSquad.UpdateAffinity(UnitRef,  (default.AFFINITY_GAIN_WHEN_ON_MISSION + default.AFFINITY_GAIN_WHEN_ON_MISSION_WON));
			}
			else
			{
				OnMissionSquad.UpdateAffinity(UnitRef,  default.AFFINITY_GAIN_WHEN_ON_MISSION);
			}
		}

			
	}
	// Squad Levels are updated later in UpdatePostMissionSquad

	// if (NewGameState.GetNumGameStateObjects() > 0)
	// {
	// 	`GAMERULES.SubmitGameState(NewGameState);
	// }
	// else
	// {
	// 	History.CleanupPendingGameState(NewGameState);
	// }

	return ELR_NoInterrupt;

}

function EventListenerReturn OverrideSpecialistRankIcon(Object EventData, Object EventSource, XComGameState NewGameState, Name InEventID, Object CallbackData)
{
	local XComGameState_Unit UnitState;
	local XComLWTuple OverrideTuple;
	local UnitValue kUnitValue;
	
	OverrideTuple = XComLWTuple(EventData);
	if (OverrideTuple == none)
	{
		`REDSCREEN("Override event triggered with invalid event data.");
		return ELR_NoInterrupt;
	}

	UnitState = XComGameState_Unit(EventSource);
	if (UnitState == none)
	{
		return ELR_NoInterrupt;
	}

	if (OverrideTuple.Id != 'SoldierRankIcon')
	{
		return ELR_NoInterrupt;
	}

	UnitState.GetUnitValue('SBR_SpecialistTrainingFactionType',kUnitValue);

	if ((kUnitValue.fValue > 0)  && (OverrideTuple.Data[0].i == -1))
	{
		if (kUnitValue.fValue > 0 && kUnitValue.fValue <= 1)
			OverrideTuple.Data[1].s = "img:///UILibrary_XPACK_Common.Faction_Reaper_1_sm";
		if (kUnitValue.fValue > 1 && kUnitValue.fValue <= 2)
			OverrideTuple.Data[1].s = "img:///UILibrary_XPACK_Common.Faction_Skirmisher_flat";
		if (kUnitValue.fValue > 2 && kUnitValue.fValue <= 3)
			OverrideTuple.Data[1].s = "img:///UILibrary_XPACK_Common.Faction_Templar_flat";
	}

	return ELR_NoInterrupt;
}