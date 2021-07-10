// XComGameState_SBRSquad
//
// Represents a single squad. Similar to and based off LW2's XComGameState_LWPersistentSquad.

class XComGameState_SBRSquad extends XComGameState_BaseObject config (SquadBasedRoster);

// Struct for tracking squad affinity amounts for each unit. As units participate in missions in this
// squad they gain affinity.
struct SquadAffinity
{
    var StateObjectReference UnitRef;
    var float Value;
};

// Affinity values for all units that have ever been in this squad, including the
// leader(s)
var array<SquadAffinity> Affinity;

// The current squad leader
var StateObjectReference Leader;

// The current specialists
var array<StateObjectReference> Specialists;

// Current squad members (includes specialists)
var array<StateObjectReference> Members;

// The faction this squad is affiliated with - only heroes of this faction
// can lead this squad.
var StateObjectReference Faction;

// User-provided (or random) squad name
var String SquadName;

// User-provided (or randon) squad logo
var String SquadLogoPath;
var string SquadBiography;  // a player-editable squad history
// The squad level. Squads rank up after enough missions have been completed.
var float SquadLevel;

// The number of missions this squad has gone on
var int NumMissions;

// Number of kills from squad members. This is not just the sum of
// all kills of all squad members, as members can be moved between squads.
var int NumKills;


var bool bOnMission;  // indicates the squad is currently deploying/(deployed?) to a mission site
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
	}
	else
	{
	class'X2StrategyGameRulesetDataStructures'.static.SetTime(StartDate, 0, 0, 0, class'X2StrategyGameRulesetDataStructures'.default.START_MONTH,
															  class'X2StrategyGameRulesetDataStructures'.default.START_DAY, class'X2StrategyGameRulesetDataStructures'.default.START_YEAR);
		DateString = class'X2StrategyGameRulesetDataStructures'.static.GetDateString(StartDate);
	}

	SquadBioTag = XGParamTag(`XEXPANDCONTEXT.FindTag("XGParam"));
	SquadBioTag.StrValue0 = DateString;
	SquadBiography = "";//`XEXPAND.ExpandString(class'UIPersonnel_SquadBarracks'.default.strDefaultSquadBiography);		
		
	return self;
}





//---------------------------
// HELPERS ---------------------
//---------------------------
function string GetUniqueRandomName(const array<string> NameList, string DefaultName)
{
	local XComGameStateHistory History;
	local XComGameState_LWSquadManager SquadMgr;
	local array<string> PossibleNames;
	local StateObjectReference SquadRef;
	local XComGameState_LWPersistentSquad SquadState;
	local XGParamTag SquadNameTag;

	History = `XCOMHISTORY;
	SquadMgr = class'XComGameState_LWSquadManager'.static.GetSquadManager();
	PossibleNames = NameList;
	foreach SquadMgr.Squads(SquadRef)
	{
		SquadState = XComGameState_LWPersistentSquad(History.GetGameStateForObjectID(SquadRef.ObjectID));
		if (SquadState == none)
			continue;

		PossibleNames.RemoveItem(SquadState.sSquadName);
	}

	if (PossibleNames.Length == 0)
	{
		SquadNameTag = XGParamTag(`XEXPANDCONTEXT.FindTag("XGParam"));
		SquadNameTag.StrValue0 = GetRightMost(string(self));
		return `XEXPAND.ExpandString(DefaultName);		
	}

	return PossibleNames[`SYNC_RAND(PossibleNames.Length)];
}