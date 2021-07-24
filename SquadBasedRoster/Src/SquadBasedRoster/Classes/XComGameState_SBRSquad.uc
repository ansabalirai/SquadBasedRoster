//---------------------------------------------------------------------------------------
//  FILE:    XComGameState_SBRSquad.uc
//  AUTHOR:  Rai
//  PURPOSE: This representes a single squad
//---------------------------------------------------------------------------------------

class XComGameState_SBRSquad extends XComGameState_BaseObject config (SquadBasedRoster);

enum ESquadStatus
{
	eStatus_Available,		// not otherwise on a mission or in training
	eStatus_Infiltration,	// Out on infiltration (CI)
	eStatus_CovertAction,	// out on a covert action
	eStatus_Training,		// With a soldier (squad leader or specialist) in a training slot (including psi/officer training)
	eStatus_Healing,		// healing up
};

var eSquadStatus SquadStatus;


// Struct for tracking squad affinity amounts for each unit. As units participate in missions in this squad they gain affinity.
struct SquadAffinity
{
    var StateObjectReference UnitRef;
    var float Value;
};

// Affinity values for all units that have ever been in this squad, including the
// leader(s)
var array<SquadAffinity> Affinity;

// This reflects the current level of the squad and is at least partially determined by the average affinity
var float SquadLevel;
var float AverageAffinity;

// The current squad leader
var StateObjectReference Leader;

// The current specialists
var array<StateObjectReference> Specialists;

// Current squad members (includes specialists)
var array<StateObjectReference> SquadSoldiers; // Which soldiers make up the squad
var array<StateObjectReference> SquadSoldiersOnMission; // possibly different from SquadSoldiers due to injury, training, or being a temporary reserve replacement

// The faction this squad is affiliated with - only heroes of this faction
// can lead this squad.
var StateObjectReference Faction;

// User-provided (or random) squad name
var String SquadName;

// User-provided (or randon) squad logo
var String SquadLogoPath;
var config string DefaultSquadImagePath;
var string SquadBiography;  // a player-editable squad history
var TDateTime SquadCreationTime;


// The number of missions this squad has gone on
var int NumMissions;
var int NumMissionsSuccessful;

// Number of kills from squad members. This is not just the sum of
// all kills of all squad members, as members can be moved between squads.
var int NumKills;


var bool bOnMission;  // indicates the squad is currently deploying/(deployed?) to a mission site
var bool bOnCovertAction; // indicates if the squad is currently deployed on a covert action
var bool bTemporary; // indicates that this squad is only for the current mission, and shouldn't be retained
var StateObjectReference CurrentMission; // the current mission being deployed to -- none if no mission

var localized array<string> DefaultSquadNames; // localizable array of default squadnames to choose from
var localized array<string> TempSquadNames; // localizable array of temporary squadnames to choose from
var localized string BackupSquadName;
var localized string BackupTempSquadName;

//---------------------------
// INIT ---------------------
//---------------------------

function XComGameState_SBRSquad InitSquad(optional string sName = "", optional bool Temp = false)
{
	local TDateTime StartDate;
	local string DateString;
	local XGParamTag SquadBioTag;
	local array<StateObjectReference> AllSoldierRefs;
	local StateObjectReference SoldierRef;

	bTemporary = Temp;

	if(sName != "")
		SquadName = sName;
	else
		if (bTemporary)
			SquadName = GetUniqueRandomName(TempSquadNames, BackupTempSquadName);
		else
			SquadName = GetUniqueRandomName(DefaultSquadNames, BackupSquadName);

	if (`GAME.GetGeoscape() != none)
	{
		DateString = class'X2StrategyGameRulesetDataStructures'.static.GetDateString(`GAME.GetGeoscape().m_kDateTime);
		SquadCreationTime = `GAME.GetGeoscape().m_kDateTime;
	}
	else
	{
	class'X2StrategyGameRulesetDataStructures'.static.SetTime(StartDate, 0, 0, 0, class'X2StrategyGameRulesetDataStructures'.default.START_MONTH,
															  class'X2StrategyGameRulesetDataStructures'.default.START_DAY, class'X2StrategyGameRulesetDataStructures'.default.START_YEAR);
		DateString = class'X2StrategyGameRulesetDataStructures'.static.GetDateString(StartDate);
		SquadCreationTime = StartDate;
	}

	
	SquadBioTag = XGParamTag(`XEXPANDCONTEXT.FindTag("XGParam"));
	SquadBioTag.StrValue0 = DateString;
	SquadBiography = "";//`XEXPAND.ExpandString(class'UIPersonnel_SquadBarracks'.default.strDefaultSquadBiography);	
	SquadLogoPath = DefaultSquadImagePath;

	// To do: Set faction, leader and specialist as well as a baseline affinity and shit
	AllSoldierRefs = class'X2Helper_SquadBasedRoster'.static.GetAllSoldierRefs();
	foreach AllSoldierRefs(SoldierRef)
	{
		UpdateAffinity(SoldierRef); //Instantiate to 0
	}
	
	return self;
}

//---------------------------
// SOLDIER HANDLING ---------
//---------------------------

function bool UnitIsInSquad(StateObjectReference UnitRef)
{
	return SquadSoldiers.Find('ObjectID', UnitRef.ObjectID) != -1;
}

function bool UnitIsInSquadOnMission(StateObjectReference UnitRef)
{
	return SquadSoldiersOnMission.Find('ObjectID', UnitRef.ObjectID) != -1;
}

function XComGameState_Unit GetSoldier(int idx)
{
	if(idx >=0 && idx < SquadSoldiers.Length)
	{
		return XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(SquadSoldiers[idx].ObjectID));
	}
	return none;
}

// Is this soldier valid for a squad? Yes as long as they aren't dead or captured.
// We also need to make sure that the soldier is the right fight for the squad affiliation. 
// For example, leaders can only be moved the relevant faction that the squad is affiliated with.

function bool IsValidSoldierForSquad(XComGameState_Unit Soldier)
{
	return Soldier.IsSoldier() && !Soldier.IsDead() && !Soldier.bCaptured;
}

function array<StateObjectReference> GetSoldierRefs(optional bool bIncludeTemp = false)
{
	local XComGameState_Unit Soldier;
	local array<StateObjectReference> SoldierRefs;
	local int idx;
	local XComGameStateHistory History;

	History = `XCOMHISTORY;
	for (idx = 0; idx < SquadSoldiers.Length; idx++)
	{
		Soldier = XComGameState_Unit(History.GetGameStateForObjectID(SquadSoldiers[idx].ObjectID));

		if (Soldier != none)
		{
			if (IsValidSoldierForSquad(Soldier))
			{
				SoldierRefs.AddItem(Soldier.GetReference());
			}
		}
	}
	if (!bIncludeTemp)
		return SoldierRefs;

	for (idx = 0; idx < SquadSoldiersOnMission.Length; idx++)
	{
		Soldier = XComGameState_Unit(History.GetGameStateForObjectID(SquadSoldiersOnMission[idx].ObjectID));

		if (Soldier != none)
		{
			if (IsValidSoldierForSquad(Soldier))
			{
				if (IsSoldierTemporary(Soldier.GetReference()))
					SoldierRefs.AddItem(Soldier.GetReference());
			}
		}
	}

	return SoldierRefs;
}


function array<XComGameState_Unit> GetSoldiers()
{
	local XComGameState_Unit Soldier;
	local array<XComGameState_Unit> Soldiers;
	local int idx;
	local XComGameStateHistory History;

	History = `XCOMHISTORY;
	for (idx = 0; idx < SquadSoldiers.Length; idx++)
	{
		Soldier = XComGameState_Unit(History.GetGameStateForObjectID(SquadSoldiers[idx].ObjectID));

		if (Soldier != none)
		{
			if (IsValidSoldierForSquad(Soldier))
			{
				Soldiers.AddItem(Soldier);
			}
		}
	}

	return Soldiers;
}

function array<XComGameState_Unit> GetTempSoldiers()
{
	local XComGameState_Unit Soldier;
	local array<XComGameState_Unit> Soldiers;
	local int idx;
	local XComGameStateHistory History;

	History = `XCOMHISTORY;
	for (idx = 0; idx < SquadSoldiersOnMission.Length; idx++)
	{
		Soldier = XComGameState_Unit(History.GetGameStateForObjectID(SquadSoldiersOnMission[idx].ObjectID));

		if (Soldier != none)
		{
			if (IsValidSoldierForSquad(Soldier))
			{
				if (IsSoldierTemporary(Soldier.GetReference()))
					Soldiers.AddItem(Soldier);
			}
		}
	}

	return Soldiers;
	
}

// Seems like the next two functions are unused, so maybe we can use this to ensure our squad comp restriction?
function array<XComGameState_Unit> GetDeployableSoldiers(optional bool bAllowWoundedSoldiers=false)
{
	local XComGameState_Unit Soldier;
	local array<XComGameState_Unit> DeployableSoldiers;
	local int idx;
	local XComGameStateHistory History;

	History = `XCOMHISTORY;
	for(idx = 0; idx < SquadSoldiers.Length; idx++)
	{
		Soldier = XComGameState_Unit(History.GetGameStateForObjectID(SquadSoldiers[idx].ObjectID));

		if(Soldier != none)
		{
			if(IsValidSoldierForSquad(Soldier) &&
				(Soldier.GetStatus() == eStatus_Active || Soldier.GetStatus() == eStatus_PsiTraining || (bAllowWoundedSoldiers && Soldier.IsInjured())))
			{
				DeployableSoldiers.AddItem(Soldier);
			}
		}
	}

	return DeployableSoldiers;
}

function array<StateObjectReference> GetDeployableSoldierRefs(optional bool bAllowWoundedSoldiers=false)
{
	local XComGameState_Unit Soldier;
	local array<StateObjectReference> DeployableSoldierRefs;
	local int idx;
	local XComGameStateHistory History;

	History = `XCOMHISTORY;
	for(idx = 0; idx < SquadSoldiers.Length; idx++)
	{
		Soldier = XComGameState_Unit(History.GetGameStateForObjectID(SquadSoldiers[idx].ObjectID));

		if(Soldier != none)
		{
			if(IsValidSoldierForSquad(Soldier) &&
				(Soldier.GetStatus() == eStatus_Active || Soldier.GetStatus() == eStatus_PsiTraining || (bAllowWoundedSoldiers && Soldier.IsInjured())))
			{
				DeployableSoldierRefs.AddItem(Soldier.GetReference());
			}
		}
	}

	return DeployableSoldierRefs;
}


function bool IsSoldierTemporary(StateObjectReference UnitRef)
{
	if (SquadSoldiersOnMission.Find('ObjectID', UnitRef.ObjectID) == -1)
		return false;
	return SquadSoldiers.Find('ObjectID', UnitRef.ObjectID) == -1;
}


// Rai - We try to add restrictions of our SBR design here on who can or cannot be added
// This function only checks unassigned soldiers, so we can assume that they do not have a permanent squad
// Note that currently squad size restriction is handled by CanTransferSoldier()
function bool CanSoldierBeAdded(StateObjectReference UnitRef)
{
	local XComGameState_Unit Soldier;
	local XComGameStateHistory History;
	local XComGameState_ResistanceFaction FactionState;
	local XComGameState_Unit_SBRSpecialist Specialist;

	History = `XCOMHISTORY;
	Soldier = XComGameState_Unit(History.GetGameStateForObjectID(UnitRef.ObjectID));

	//FactionState = XComGameState_ResistanceFaction(History.GetGameStateForObjectID(Faction.ObjectID));
	// We cannot assign more than 1 hero class (of any type) to a squad
	if (Soldier.IsResistanceHero() && Leader.ObjectID != 0)
	{
		return false;
	}

	// Just an ordinary soldier
	return true;
}


// Rai - We try to add restrictions of our SBR design here on who can or cannot be removed
// This function only checks current soldiers in squad
// Note that currently squad size restriction is handled by CanTransferSoldier()
function bool CanSoldierBeRemoved(StateObjectReference UnitRef)
{
	local XComGameState_Unit Soldier;
	local XComGameStateHistory History;
	local XComGameState_ResistanceFaction FactionState;
	local XComGameState_Unit_SBRSpecialist Specialist;
	local StateObjectReference NullRef;

	History = `XCOMHISTORY;
	Soldier = XComGameState_Unit(History.GetGameStateForObjectID(UnitRef.ObjectID));

	/// Currently all handling for squad levels and shit is being handled by UpdateSquadStatus,
	return true;
}


function AddSoldier(StateObjectReference UnitRef)
{
	local StateObjectReference SoldierRef;
	local int idx;

	// the squad may have "blank" ObjectIDs in order to allow player to arrange squad as desired
	// so, when adding a new soldier generically, try and find an existing ObjectID == 0 to fill before adding
	// This is a fix for ID 863
	foreach SquadSoldiers(SoldierRef, idx)
	{
		if (SoldierRef.ObjectID == 0)
		{
			SquadSoldiers[idx] = UnitRef;
			return;
		}
	}
	SquadSoldiers.AddItem(UnitRef);
	UpdateSquadStatus(UnitRef, true);
}

function RemoveSoldier(StateObjectReference UnitRef)
{
	SquadSoldiers.RemoveItem(UnitRef);
	UpdateSquadStatus(UnitRef, false);
}

function int GetSquadCount()
{
	return GetSquadCount_Static(SquadSoldiers);
}

static function int GetSquadCount_Static(array<StateObjectReference> Soldiers)
{
	local int idx, Count;


	for(idx = 0; idx < Soldiers.Length; idx++)
	{
		if(Soldiers[idx].ObjectID > 0)
			Count++;
	}
	return Count;
}

function string GetSquadImagePath()
{
	if(SquadLogoPath != "")
		return SquadLogoPath;

	return default.DefaultSquadImagePath;
}

// Rai - To DO: Upon adding or removing a soldier, we need to update the squad affiliation to faction, affinity, level and so on
// We also need to think what to do for the case when a temporary squad is formed, i.e. how to update the SL in that case
function UpdateSquadStatus(StateObjectReference UnitRef, bool bAdded)
{
	local XComGameStateHistory History;
	local XComGameState_Unit_SBRSpecialist Specialist;
	local XComGameState_Unit UnitState;
	local XComGameState_ResistanceFaction FactionState;
	local StateObjectReference NullState;

	History = `XCOMHISTORY;
	UnitState = XComGameState_Unit(History.GetGameStateForObjectID(UnitRef.ObjectID));
	Specialist = class'XComGameState_Unit_SBRSpecialist'.static.GetSpecialistComponent(UnitState);

	if (UnitState == none)
		return;

	if (bAdded)
	{
		if (UnitState.IsResistanceHero())
		{
			Leader = UnitState.GetReference();
			Faction = UnitState.FactionRef;
			return;
		}
		else if (Specialist != none)
		{
			FactionState = XComGameState_ResistanceFaction(History.GetGameStateForObjectID(Faction.ObjectID));
			if ((Faction.ObjectID > 0) && 
				(Specialist.FactionName == FactionState.GetMyTemplateName()) &&
				GetNumSpecialistAllowed() > 0)
			{
				Specialist.CurrentAssignedSquad = self.GetReference(); //not sure if this works
				Specialist.CurrentRank = Specialist.SpecialistRank;
				Specialists.AddItem(UnitRef);
			}
			// This is a factionless/leaderless squad or over its specialist limit, so specialist becomes a normal soldier
			// To do: How to remove the specialist component temporarily somehow
			else if (Faction.ObjectID == 0) 
			{
				Specialist.CurrentAssignedSquad = self.GetReference(); //not sure if this works
				Specialist.CurrentRank = 0;
			}			
			return;
		}
		else //Just a normal solider
		{
			// Some additional handling as needed
		}
	}
	else // Removed soldier case
	{
		if (UnitState.IsResistanceHero())
		{
			Leader = NullState;
			Faction = NullState;
			return;
		}

		else if (Specialist != none)
		{
			Specialist.CurrentAssignedSquad = NullState;
			Specialist.CurrentRank = 0;
			Specialists.RemoveItem(UnitRef);
			return;
		}
		else //Just a normal solider
		{
			// Some additional handling as needed
		}

	}
}




//---------------------------
// MISSION HANDLING ---------
//---------------------------

simulated function SetSquadCrew(optional XComGameState UpdateState, 
								optional bool bOnMissionSoldiers = true, optional bool bForDisplayOnly)
{
	local XComGameStateHistory History;
	local XComGameState_HeadquartersXCom XComHQ;
	local bool bSubmitOwnGameState, bAllowWoundedSoldiers;
	local array<StateObjectReference> SquadSoldiersToAssign;
	local StateObjectReference UnitRef;
	local XComGameState_Unit UnitState;
	local XComGameState_MissionSite MissionSite;
	local int MaxSoldiers, idx;
	local array<name> RequiredSpecialSoldiers;

	bSubmitOwnGameState = UpdateState == none;

	if(bSubmitOwnGameState)
		UpdateState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Set Persistent Squad Members");

	History = `XCOMHISTORY;

	//try and retrieve XComHQ from GameState if possible
	XComHQ = `XCOMHQ;
	XComHQ = XComGameState_HeadquartersXCom(UpdateState.GetGameStateForObjectID(XComHQ.ObjectID));
	if(XComHQ == none)
		XComHQ = `XCOMHQ;

	if (XComHQ.MissionRef.ObjectID != 0)
	{
		MissionSite = XComGameState_MissionSite(History.GetGameStateForObjectID(XComHQ.MissionRef.ObjectID));
	}

	MaxSoldiers = class'X2StrategyGameRulesetDataStructures'.static.GetMaxSoldiersAllowedOnMission(MissionSite);
	if (MissionSite != None)
	{
		bAllowWoundedSoldiers = MissionSite.GeneratedMission.Mission.AllowDeployWoundedUnits;
	}

	XComHQ = XComGameState_HeadquartersXCom(UpdateState.ModifyStateObject(class'XComGameState_HeadquartersXCom', XComHQ.ObjectID));

	if (bOnMissionSoldiers)
	{
		SquadSoldiersToAssign = SquadSoldiersOnMission;
	}
	else
	{
		if (bForDisplayOnly)
		{
			SquadSoldiersToAssign = SquadSoldiers;
		}
		else
		{
			SquadSoldiersToAssign = GetDeployableSoldierRefs(bAllowWoundedSoldiers);
		}
	}

	//clear the existing squad as much as possible (leaving in required units if in SquadSelect)
	// we can clear special units when assigning for infiltration or viewing
	if (bOnMissionSoldiers)
	{
		XComHQ.Squad.Length = 0;
	}
	else
	{
		RequiredSpecialSoldiers = MissionSite.GeneratedMission.Mission.SpecialSoldiers;

		for (idx = XComHQ.Squad.Length - 1; idx >= 0; idx--)
		{
			UnitState = XComGameState_Unit(History.GetGameStateForObjectID(XComHQ.Squad[idx].ObjectID));
			if (UnitState != none && RequiredSpecialSoldiers.Find(UnitState.GetMyTemplateName()) != -1)
			{
			}
			else
			{
				XComHQ.Squad.Remove(idx, 1);
			}
		}
	}

	//fill out the squad as much as possible using the squad units
	foreach SquadSoldiersToAssign(UnitRef)
	{
		if (XComHQ.Squad.Length >= MaxSoldiers) { continue; }

		if (UnitRef.ObjectID != 0)
		{
			UnitState = XComGameState_Unit(History.GetGameStateForObjectID(UnitRef.ObjectID));
			if (UnitState != none)
			{
				if (IsValidSoldierForSquad(UnitState))
				{
					XComHQ.Squad.AddItem(UnitRef);
				}
			}
		}
	}

	// Only update AllSquads if we're dealing with soldiers already
	// on a mission (and ready to launch).
	if (bOnMissionSoldiers)
	{
		// Borrowed from Covert Infiltration mod:
		// This isn't needed to properly spawn units into battle, but without this
		// the transition screen shows last selection in strategy, not the soldiers
		// on this mission.
		XComHQ.AllSquads.Length = 1;
		XComHQ.AllSquads[0].SquadMembers = XComHQ.Squad;
	}


	if(bSubmitOwnGameState)
		`GAMERULES.SubmitGameState(UpdateState);
}

function SetOnMissionSquadSoldierStatus(XComGameState NewGameState)
{
	local StateObjectReference UnitRef;
	local XComGameState_Unit UnitState;

	foreach SquadSoldiersOnMission(UnitRef)
	{
		UnitState = XComGameState_Unit(NewGameState.GetGameStateForObjectID(UnitRef.ObjectID));
		if(UnitState == none && UnitRef.ObjectID != 0)
		{
			UnitState = XComGameState_Unit(NewGameState.CreateStateObject(class'XComGameState_Unit', UnitRef.ObjectID));
			NewGameState.AddStateObject(UnitState);
		}
		if (UnitState != none)
		{
			SetOnMissionStatus(UnitState, NewGameState);
		}
	}
}




// Rai - Since I dont know how to set the soldier status on mission when sending out an infiltration squad, this mod does the heavy lifting
// by cheating to update the status for soldiers/squad once they return from the mission
function PostMissionRevertSoldierStatus(XComGameState NewGameState, XComGameState_SBRSquadManager SquadMgr)
{
	//local XComGameStateHistory History;
	local XComGameState_HeadquartersXCom XComHQ;
	local StateObjectReference UnitRef;
	local XComGameState_Unit UnitState;
	local XComGameState_HeadquartersProjectPsiTraining PsiProjectState;
	local XComGameState_FacilityXCom FacilityState;
	local XComGameState_StaffSlot SlotState;
	local int SlotIndex, idx;
	local StaffUnitInfo UnitInfo;
	local XComGameState_SBRSquad SquadState, UpdatedSquad;

	//History = `XCOMHISTORY;
	XComHQ = `XCOMHQ;
	foreach SquadSoldiersOnMission(UnitRef)
	{
		if (UnitRef.ObjectID == 0)
			continue;

		UnitState = XComGameState_Unit(NewGameState.GetGameStateForObjectID(UnitRef.ObjectID));
		if(UnitState == none)
		{
			UnitState = XComGameState_Unit(NewGameState.CreateStateObject(class'XComGameState_Unit', UnitRef.ObjectID));
			if (UnitState == none)
				continue;
			NewGameState.AddStateObject(UnitState);
		}
		
		//if solder is dead or captured, remove from squad
		if(UnitState.IsDead() || UnitState.bCaptured)
		{
			RemoveSoldier(UnitRef);
			// Also find if the unit was a persistent member of another squad, and remove from that squad as well if so - ID 1675
			for(idx = 0; idx < SquadMgr.Squads.Length; idx++)
			{
				SquadState = SquadMgr.GetSquad(idx);
				if(SquadState.UnitIsInSquad(UnitRef))
				{
					UpdatedSquad = XComGameState_SBRSquad(NewGameState.GetGameStateForObjectID(SquadState.ObjectID));
					if (UpdatedSquad == none)
					{
						UpdatedSquad = XComGameState_SBRSquad(NewGameState.CreateStateObject(class'XComGameState_SBRSquad', SquadState.ObjectID));
						NewGameState.AddStateObject(UpdatedSquad);
					}
					UpdatedSquad.RemoveSoldier(UnitRef);
					break;	
				}
			}
		}

		//if soldier has an active psi training project, handle it if needed
		PsiProjectState = XComHQ.GetPsiTrainingProject(UnitState.GetReference());
		if (PsiProjectState != none) // A paused Psi Training project was found for the unit
		{
			if(UnitState.GetStatus() != eStatus_PsiTraining) // if the project wasn't already resumed (e.g. during typical post-mission processing)
			{
				//following code was copied from XComGameStateContext_StrategyGameRule.SquadTacticalToStrategyTransfer

				if (UnitState.IsDead() || UnitState.bCaptured) // The unit died or was captured, so remove the project
				{
					XComHQ.Projects.RemoveItem(PsiProjectState.GetReference());
					NewGameState.RemoveStateObject(PsiProjectState.ObjectID);
				}
				else if (!UnitState.IsInjured() && UnitState.GetMentalState() == eMentalState_Ready) // If the unit is uninjured, restart the training project automatically
				{
					// Get the Psi Chamber facility and staff the unit in it if there is an open slot
					FacilityState = XComHQ.GetFacilityByName('PsiChamber'); // Only one Psi Chamber allowed, so safe to do this

					for (SlotIndex = 0; SlotIndex < FacilityState.StaffSlots.Length; ++SlotIndex)
					{
						//If this slot has not already been modified (filled) in this tactical transfer, check to see if it's valid
						SlotState = XComGameState_StaffSlot(NewGameState.GetGameStateForObjectID(FacilityState.StaffSlots[SlotIndex].ObjectID));
						if (SlotState == None)
						{
							SlotState = FacilityState.GetStaffSlot(SlotIndex);

							// If this is a valid soldier slot in the Psi Lab, restaff the soldier and restart their training project
							if (!SlotState.IsLocked() && SlotState.IsSlotEmpty() && SlotState.IsSoldierSlot())
							{
								// Restart the paused training project
								PsiProjectState = XComGameState_HeadquartersProjectPsiTraining(NewGameState.CreateStateObject(class'XComGameState_HeadquartersProjectPsiTraining', PsiProjectState.ObjectID));
								NewGameState.AddStateObject(PsiProjectState);
								PsiProjectState.bForcePaused = false;

								UnitInfo.UnitRef = UnitState.GetReference();
								SlotState.FillSlot(UnitInfo, NewGameState);

								break;
							}
						}
					}
				}
			}
		}

		//if soldier still has OnMission status, set status to active (unless it's a SPARK that's healing)
		if(IsUnitOnMission(UnitState) && UnitState.GetStatus() != eStatus_Healing)
		{
			UnitState.SetStatus(eStatus_Active);
			UpdateUnitWillRecoveryProject(UnitState);
		}
	}
}



function bool IsDeployedOnMission()
{
	local StateObjectReference SoldierRef;
	local XComGameState_Unit Soldier;
	local int idx;
	SquadStatus = eStatus_Available;

	// We need to add some logic to when the squad is considered available or not, regardless of whether it is on mission or not
	// We first assume that if a leader (assumeing we have one) is deployed on an infiltration mission, the squad is considered as infiltrating and thus not available
	// Else if, we can check if a specialist assigned ot the squad is available (not done yet)
	// Else, the squad can be considered as available only if all soldiers are available (i.e. not infiltrating)

	if (Leader.ObjectID != 0) // we have a leader, so we base squad availablility on their availability
	{
		Soldier = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(Leader.ObjectID));
		if ((Soldier.GetStaffSlot() != none && Soldier.GetStaffSlot().GetMyTemplateName() == 'InfiltrationStaffSlot'))
		{
			SquadStatus = eStatus_Infiltration;
 			bOnMission = TRUE;
			return TRUE;
		}
/* 		else if (Soldier.GetStatus() == eStatus_CovertAction)
		{
			SquadStatus = eStatus_CovertAction;
 			bOnMission = TRUE;
			return TRUE;
		} */

		// maybe add additional conditions for when the leader if training or injured, etc.
		else
		{
			SquadStatus = eStatus_Available;
 			bOnMission = FALSE;
			return FALSE;
		}

	}


	foreach SquadSoldiers(SoldierRef, idx)
	{
		if (SoldierRef.ObjectID != 0) 
		{
/* 			Soldier = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(SoldierRef.ObjectID));
			if ((Soldier.GetReference() == Leader) && (Soldier.GetStaffSlot() != none && Soldier.GetStaffSlot().GetMyTemplateName() == 'InfiltrationStaffSlot'))
			{
				SquadStatus = eStatus_Infiltration;
				bOnMission = TRUE;
				return TRUE;
			}

			else if ((Soldier.GetReference() == Leader) && (Soldier.GetStatus() == eStatus_CovertAction))
			{
				SquadStatus = eStatus_CovertAction;
				bOnMission = TRUE;
				return TRUE;
			} */
			if ((Soldier.GetStaffSlot() != none && Soldier.GetStaffSlot().GetMyTemplateName() == 'InfiltrationStaffSlot'))
			{
				SquadStatus = eStatus_Infiltration;
				bOnMission = TRUE;
				return TRUE;
			}
		}
	}

	SquadStatus = eStatus_Available;
 	bOnMission = FALSE;
	return FALSE;
	// We come here if there is no squad leader (which normally should not happen), but in this case,
	// squad is considered available only when all units are available
/* 	else 
	{
		if (GetDeployableSoldiers(false).Length == 0 && GetSoldiers().Length > 0) // this accounts for empty squad for some reason
		{
			bOnMission = TRUE;
			return TRUE;
		}
		else
		{
			bOnMission = FALSE;
			return FALSE;
		}

	} */

}


// Checks if a soldier is part of a squad
function StateObjectReference GetSquadLeaderRef()
{
	local StateObjectReference NullRef;
	if (Leader.ObjectID != 0)
		return Leader;

	return NullRef;
}




// Print the status and location for all soldiers in all squads
function GetSquadSoldierStatus()
{
	local StateObjectReference SoldierRef;
	local array<StateObjectReference> SoldiersRefs, NullRef;
	local XComGameState_Unit Soldier;
	local XComGameState_ResistanceFaction FactionState;
	local int idx;
	local float AA;
	local string SoldierStatus;

	`LOG("-------------------------------------------------------------------");
	if (SquadStatus == eStatus_Infiltration)
		`LOG("SquadBasedRoster: Squad Name: " $ SquadName $ " Status is On Infiltration");
	else if (bOnMission)
		`LOG("SquadBasedRoster: Squad Name: " $ SquadName $ " Status is On Mission" );
	else
		`LOG("SquadBasedRoster: Squad Name: " $ SquadName $ " Status is Available" );

	AA = int(GetAverageAffinity(SquadSoldiers)*100)/100;
	`LOG("SquadBasedRoster: SL: " $ Int(SquadLevel) $ " AA: " $ string(AA));
	Soldier = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(Leader.ObjectID));
	FactionState = XComGameState_ResistanceFaction(`XCOMHISTORY.GetGameStateForObjectID(Faction.ObjectID));
	SoldierStatus = Soldier.GetName(eNameType_Full);
	if (Leader.ObjectID > 0)
	{
		`LOG("SquadBasedRoster: Squad Leader: " $ SoldierStatus $ ", Faction: " $ FactionState.GetMyTemplateName());
	}
		
	// Add affinity and squad level info etc.



	foreach SquadSoldiers(SoldierRef, idx)
	{
		Soldier = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(SoldierRef.ObjectID));
		SoldierStatus = Soldier.GetName(eNameType_Full);
		if (SoldierRef.ObjectID != 0) 
		{
			
			if (IsSoldierInfiltratingCI(SoldierRef))
				SoldierStatus $= ", Status: On Infiltration (CI)";
			
			else
			{
				switch ( Soldier.GetStatus() )
				{
				case eStatus_Active:
					SoldierStatus $= ", Status: Active";
					break;
				case eStatus_Healing:
					SoldierStatus $= ", Status: Healing/Injured";
					break;
				case eStatus_OnMission:
					SoldierStatus $= ", Status: Deployed on Mission";
					break;
				case eStatus_PsiTesting:
					SoldierStatus $= ", Status: Psi Training";
					break;
				case eStatus_Training:
					SoldierStatus $= ", Status: Training";
					break;
				case eStatus_CovertAction:
					SoldierStatus $= ", Status: On Covert Action";
					break;
				}				
			}			

			SoldierStatus $= ", Affinity: ";
			SoldiersRefs = NullRef;
			SoldiersRefs.AddItem(SoldierRef);
			SoldierStatus $= string(GetAverageAffinity(SoldiersRefs));

			SoldierStatus $= ", EL: ";
			SoldiersRefs = NullRef;
			SoldiersRefs.AddItem(SoldierRef);
			SoldierStatus $= string(GetEffectiveLevel(SoldierRef)); // EL based on current squad composition (i.e. not while on mission)

/* 			SoldierStatus $= ", Location: ";
			switch ( Soldier.GetHQLocation() )
			{
			case eSoldierLoc_Barracks:
				SoldierStatus $= "Barracks";
				break;
			case eSoldierLoc_Dropship:
				SoldierStatus $= "Dropship";
				break;
			case eSoldierLoc_Infirmary:
				SoldierStatus $= "Infirmary";
				break;
			case eSoldierLoc_Armory:
				SoldierStatus $= "Armory";
				break;
			case eSoldierLoc_MedalCeremony:
				SoldierStatus $= "Medal Ceremony";
				break;
			} */
			
		}
		`LOG("SquadBasedRoster: " $ SoldierStatus);
	}
	`LOG("-------------------------------------------------------------------");
}



function bool IsSoldierOnMission(StateObjectReference UnitRef)
{
	return SquadSoldiersOnMission.Find('ObjectID', UnitRef.ObjectID) >= 0;
}

function bool IsSoldierInfiltratingCI(StateObjectReference UnitRef)
{
	local XComGameState_Unit Soldier;
	local StateObjectReference NullRef;

	Soldier = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(UnitRef.ObjectID));
	if (Soldier == none)
		return false;

	if ((Soldier.GetStaffSlot() != none && Soldier.GetStaffSlot().GetMyTemplateName() == 'InfiltrationStaffSlot'))
		return true;

	else
		return false;
}


function XComGameState_MissionSite GetCurrentMission()
{
	if(CurrentMission.ObjectID == 0)
		return none;
	return XComGameState_MissionSite(`XCOMHISTORY.GetGameStateForObjectID(CurrentMission.ObjectID));
}

function StartMission(StateObjectReference MissionRef)
{
	local XComGameState UpdateState;
	local XComGameState_SBRSquad UpdateSquad;

	UpdateState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Start Infiltration Mission");
	UpdateSquad = XComGameState_SBRSquad(UpdateState.CreateStateObject(class'XComGameState_SBRSquad', ObjectID));
	//UpdateSquad.InitInfiltration(MissionRef);
	UpdateState.AddStateObject(UpdateSquad);
	`XCOMGAME.GameRuleset.SubmitGameState(UpdateState);
}

function SetMissionStatus( StateObjectReference MissionRef)
{
	CurrentMission = MissionRef;
	bOnMission = true;
}

function ResetMissionStatus()
{
	bOnMission = false;
}

function ClearMission()
{
	bOnMission = false;
	SquadSoldiersOnMission.Length = 0;	
	CurrentMission.ObjectID = 0;
}

//---------------------------
// AFFINITY RELATED ---------
//---------------------------

function UpdateAffinity(StateObjectReference UnitRef, optional int Count=0)
{
	local int idx;
	local SquadAffinity Entry, EmptyEntry;
	local bool bFoundExistingEntry;

	foreach Affinity (Entry, idx)
	{
		if (Entry.UnitRef.ObjectID == UnitRef.ObjectID)
		{
			bFoundExistingEntry = true;
			break;
		}
	}

	if (bFoundExistingEntry)
	{
		Affinity[idx].Value += Count;
		Affinity[idx].Value = Max(Affinity[idx].Value, 0);
	}

	else
	{
		Entry = EmptyEntry;
		Entry.UnitRef = UnitRef;
		Entry.Value = Max(Count,0);
		Affinity.AddItem(Entry);
	}
}

// This computes the average affinity of the provided set of soldiers for THIS squad
function float GetAverageAffinity (array<StateObjectReference> SoldierRefs)
{
	local int idx;
	local StateObjectReference UnitRef;
	local SquadAffinity Entry, EmptyEntry;
	local float outAffinity;

	foreach SoldierRefs(UnitRef)
	{
		foreach Affinity (Entry, idx)
		{
			if (Entry.UnitRef.ObjectID == UnitRef.ObjectID)
			{
				outAffinity += Affinity[idx].Value;
				break;
			}
		}
	}
	
	return outAffinity/(SoldierRefs.Length);
}

function float GetUnitAffinity (StateObjectReference SoldierRef)
{
	local int idx;
	local StateObjectReference UnitRef;
	local SquadAffinity Entry, EmptyEntry;
	local float outAffinity;


	foreach Affinity (Entry, idx)
	{
		if (Entry.UnitRef.ObjectID == SoldierRef.ObjectID)
		{
			return Affinity[idx].Value;
		}
	}
	
	return 0;
}

// This computes the EL for a given soldier based on the SA and AA computed with respect to THIS squad
function float GetEffectiveLevel (StateObjectReference SoldierRef)
{
	local float SA, AA, EL;

	SA = GetUnitAffinity(SoldierRef);
	AA = GetAverageAffinity(SquadSoldiers);

	EL = SA * class'XComGameState_SBRSquadManager'.default.SOLDIER_AFFINITY_FACTOR + 
		 AA * class'XComGameState_SBRSquadManager'.default.AVERAGE_AFFINITY_FACTOR +
		 SquadLevel * class'XComGameState_SBRSquadManager'.default.SQUAD_LEVEL_FACTOR;

	// Clamped between 0 and 20
	EL = FMin((EL/2), class'XComGameState_SBRSquadManager'.default.MAX_SOLDIER_EFFECTIVE_LEVEL);
	EL = FMax(0,EL);

	// Some experimental scaling for reverse difficulty curve
	if (EL > 0 && EL <= 5)
	{
		EL = EL*2;
		EL = FMin(EL,5);
	}
	else if (EL > 5 && EL <= 10)
	{
		EL = EL*1.5;
		EL = FMin(EL,10);
	}
	else if (EL > 10 && EL <= 15)
	{
		EL = EL*1.25;
		EL = FMin(EL,15);
	}

	return EL;
}

// This computes the EL for a given soldier based on the SA and AA of the provided set of soldiers, computed with respect to THIS squad. This one is called at the start of the mission to assign the correct EL to units
function float GetEffectiveLevelOnMission (StateObjectReference SoldierRef, array<StateObjectReference> SoldierRefs)
{
	local float SA, AA, EL;
	local StateObjectReference UnitRef;

	SA = GetUnitAffinity(SoldierRef);
	AA = GetAverageAffinity(SoldierRefs);

	EL = SA * class'XComGameState_SBRSquadManager'.default.SOLDIER_AFFINITY_FACTOR + 
		 AA * class'XComGameState_SBRSquadManager'.default.AVERAGE_AFFINITY_FACTOR +
		 SquadLevel * class'XComGameState_SBRSquadManager'.default.SQUAD_LEVEL_FACTOR;

	

	// If the squad has a faction leader and it is included in current deployed squad, bump the EL by this configured amount
	if (Leader.ObjectID != 0 && (SoldierRefs.Find('ObjectID', Leader.ObjectID) != -1))
	{

		EL += (2*class'XComGameState_SBRSquadManager'.default.LEADER_EFFECTIVE_LEVEL_BUMP); // Halves as per below

	}


	// Clamped between 0 and 20
	EL = FMin((EL/2), class'XComGameState_SBRSquadManager'.default.MAX_SOLDIER_EFFECTIVE_LEVEL);
	EL = FMax(0,EL);

	// Some experimental scaling for reverse difficulty curve
	if (EL > 0 && EL <= 5)
	{
		EL = EL*2;
		EL = FMin(EL,5);
	}
	else if (EL > 5 && EL <= 10)
	{
		EL = EL*1.5;
		EL = FMin(EL,10);
	}
	else if (EL > 10 && EL <= 15)
	{
		EL = EL*1.25;
		EL = FMin(EL,15);
	}

	return EL;
}



//---------------------------
// HELPERS ---------------------
//---------------------------
function string GetUniqueRandomName(const array<string> NameList, string DefaultName)
{
	local XComGameStateHistory History;
	local XComGameState_SBRSquadManager SquadMgr;
	local array<string> PossibleNames;
	local StateObjectReference SquadRef;
	local XComGameState_SBRSquad SquadState;
	local XGParamTag SquadNameTag;

	History = `XCOMHISTORY;
	SquadMgr = class'XComGameState_SBRSquadManager'.static.GetSquadManager();
	PossibleNames = NameList;
	foreach SquadMgr.Squads(SquadRef)
	{
		SquadState = XComGameState_SBRSquad(History.GetGameStateForObjectID(SquadRef.ObjectID));
		if (SquadState == none)
			continue;

		PossibleNames.RemoveItem(SquadState.SquadName);
	}

	if (PossibleNames.Length == 0)
	{
		SquadNameTag = XGParamTag(`XEXPANDCONTEXT.FindTag("XGParam"));
		SquadNameTag.StrValue0 = GetRightMost(string(self));
		return `XEXPAND.ExpandString(DefaultName);		
	}

	return PossibleNames[`SYNC_RAND(PossibleNames.Length)];
}

// helper for sparks to resolve if a wounded spark is on a mission, since that status can override the OnMission one
static function bool IsUnitOnMission(XComGameState_Unit UnitState)
{
	switch (UnitState.GetMyTemplateName())
	{
		case  'SparkSoldier':
			//sparks can be wounded and on a mission, so instead we have to do a more brute force check of existing squads and havens
			if (UnitState.GetStatus() == eStatus_CovertAction)
			{
				return true;
			}
			if (class'XComGameState_SBRSquadManager'.static.GetSquadManager().UnitIsOnMission(UnitState.GetReference()))
			{
				return true;
			}
			break;
		default:
			return UnitState.GetStatus() == eStatus_CovertAction;
			break;
	}
	return false;
}

// helper for sparks to update healing project and staffslot
static function SetOnMissionStatus(XComGameState_Unit UnitState, XComGameState NewGameState)
{
	local XComGameState_StaffSlot StaffSlotState;
	local XComGameState_HeadquartersProjectHealSoldier HealSparkProject;

	switch (UnitState.GetMyTemplateName())
	{
		case  'SparkSoldier':
			//sparks can be wounded and set on a mission, in which case don't update their status, but pull them from the healing bay
			if (UnitState.GetStatus() == eStatus_Healing)
			{
				//if it's in a healing slot, remove it from slot
				StaffSlotState = UnitState.GetStaffSlot();
				if(StaffSlotState != none)
				{
					StaffSlotState.EmptySlot(NewGameState);
				}
				//and pause any healing project
				HealSparkProject = GetHealSparkProject(UnitState.GetReference());
				if (HealSparkProject != none)
				{
					HealSparkProject.PauseProject();
				}
			}
			break;
		default:
			break;
	}
	UnitState.SetStatus(eStatus_CovertAction);
	UpdateUnitWillRecoveryProject(UnitState);
}

//helper to retrieve spark heal project -- note that we can't retrieve the proper project, since it is in the DLC3.u
// so instead we retrieve the parent heal project class and check using IsA
static function XComGameState_HeadquartersProjectHealSoldier GetHealSparkProject(StateObjectReference UnitRef)
{
    local XComGameStateHistory History;
    local XComGameState_HeadquartersXCom XCOMHQ;
    local XComGameState_HeadquartersProjectHealSoldier HealSparkProject;
    local int Idx;

    History = `XCOMHISTORY;
    XCOMHQ = `XCOMHQ;
    for(Idx = 0; Idx < XCOMHQ.Projects.Length; ++ Idx)
    {
        HealSparkProject = XComGameState_HeadquartersProjectHealSoldier(History.GetGameStateForObjectID(XCOMHQ.Projects[Idx].ObjectID));
        if(HealSparkProject != none && HealSparkProject.IsA('XComGameState_HeadquartersProjectHealSpark'))
        {
            if(UnitRef == HealSparkProject.ProjectFocus)
            {
                return HealSparkProject;
            }
        }
    }
    return none;
}

static function UpdateUnitWillRecoveryProject(XComGameState_Unit UnitState)
{
	local XComGameState_HeadquartersProjectRecoverWill WillProject;
	local ESoldierStatus UnitStatus;

	// Pause or resume the unit's Will recovery project if there is one, based on
	// the new status.
	WillProject = GetWillRecoveryProject(UnitState.GetReference());
	if (WillProject != none)
	{
		UnitStatus = UnitState.GetStatus();
		if ((UnitStatus == eStatus_Active || UnitStatus == eStatus_Healing) && IsHQProjectPaused(WillProject))
		{
			WillProject.ResumeProject();
		}
		else if ((UnitStatus != eStatus_Active && UnitStatus != eStatus_Healing) && !IsHQProjectPaused(WillProject))
		{
			WillProject.PauseProject();
		}
	}
}
static function bool IsHQProjectPaused(XComGameState_HeadquartersProject ProjectState)
{
	return ProjectState.CompletionDateTime.m_iYear == 9999;
}

static function XComGameState_HeadquartersProjectRecoverWill GetWillRecoveryProject(StateObjectReference UnitRef)
{
	local XComGameState_HeadquartersProjectRecoverWill WillProject;

	foreach `XCOMHISTORY.IterateByClassType(class'XComGameState_HeadquartersProjectRecoverWill', WillProject)
	{
		if (WillProject.ProjectFocus.ObjectID == UnitRef.ObjectID)
		{
			return WillProject;
		}
	}

	return none;
}


static function int GetNumSpecialistAllowed()
{
	// Depending on squad size upgrade or CI infil unlocks
	if ((`XCOMHQ.HasSoldierUnlockTemplate('InfiltrationSize1') || `XCOMHQ.HasSoldierUnlockTemplate('SquadSizeIUnlock')))
		return Max(1 - (default.Specialists.Length), 0);

	if ((`XCOMHQ.HasSoldierUnlockTemplate('InfiltrationSize2') || `XCOMHQ.HasSoldierUnlockTemplate('SquadSizeIIUnlock')))
		return Max(2 - (default.Specialists.Length), 0);

	return 0;
}


//---------------------------
// MISC SETTINGS ------------
//---------------------------

function string GetSquadName()
{
	return SquadName;
}

function SetSquadName(string NewName)
{
	SquadName = NewName;
}