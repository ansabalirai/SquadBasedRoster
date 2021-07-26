//---------------------------------------------------------------------------------------
//  FILE:    X2Ability_Camaraderie.uc
//  AUTHOR:  Rai / (Copied from RM's Squad Cohesion mod with permission)
//  PURPOSE: Creates a generic ability to give squad boosts to units based on EL
//--------------------------------------------------------------------------------------- 

class X2Effect_Camaraderie extends X2Effect_ModifyStats config(SquadBasedRoster);

var config float AIM_BASE;
var config float CRIT_BASE;
var config float WILL_BASE;
var config float MOBILITY_BASE;
var config float DEFENSE_BASE;
var config float DODGE_BASE;
var config float HACKING_BASE;
var config float ARMOR_BASE;
var config float PSI_BASE;


simulated protected function OnEffectAdded(const out EffectAppliedData ApplyEffectParameters, XComGameState_BaseObject kNewTargetState, XComGameState NewGameState, XComGameState_Effect NewEffectState)
{
	local XComGameState_Unit SourceUnit;

	SourceUnit = XComGameState_Unit(NewGameState.GetGameStateForObjectID(ApplyEffectParameters.SourceStateObjectRef.ObjectID));
	if (SourceUnit == none)
		SourceUnit = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(ApplyEffectParameters.SourceStateObjectRef.ObjectID));
	`assert(SourceUnit != none);

	CalculateCamaraderieStats(SourceUnit, XComGameState_Unit(kNewTargetState), NewEffectState);
	
	super.OnEffectAdded(ApplyEffectParameters, kNewTargetState, NewGameState, NewEffectState);
}

simulated protected function CalculateCamaraderieStats(XComGameState_Unit SourceUnit, XComGameState_Unit TargetUnit, XComGameState_Effect EffectState)
{

	local StatChange Camaraderie;
    local XComGameState_HeadquartersXCom XComHQ;
    local XComGameState_Unit Solider;
    local XComGameState_SBRSquadManager SquadMgr;
    local XComGameState_SBRSquad Squad;
    local StateObjectReference SoldierRef;
    local float EL;
    local int idx;

    XComHQ = `XCOMHQ;
    SquadMgr = class'XComGameState_SBRSquadManager'.static.GetSquadManager();
    if (SquadMgr == none)
        `REDSCREEN("SquadManager not found when calculating camaraderie stats");

    for (idx = 0; idx < SquadMgr.Squads.Length; idx++)
	{
        /// Find out which squad is the one mission
        Squad = XComGameState_SBRSquad(`XCOMHISTORY.GetGameStateForObjectID(SquadMgr.Squads[idx].ObjectID));
        if (Squad.bOnMission == TRUE && Squad.SquadStatus == eStatus_OnMission)
        {
            EL = Squad.GetEffectiveLevelOnMission(TargetUnit.GetReference(), XComHQ.Squad);
            break;
        }
    }

    `Log("SquadBasedRoster: EL for Camaraderie computation for " @ TargetUnit.GetFullName() @ "is " @ string(EL));



	//Aim
		Camaraderie.StatType = eStat_Offense;
		Camaraderie.StatAmount = default.AIM_BASE * int(EL);
		EffectState.StatChanges.AddItem(Camaraderie);
	
	//Crit

		Camaraderie.StatType = eStat_CritChance;
		Camaraderie.StatAmount = default.CRIT_BASE* int(EL);
		EffectState.StatChanges.AddItem(Camaraderie);

	// Will

		Camaraderie.StatType = eStat_Will;
		Camaraderie.StatAmount = default.WILL_BASE* int(EL);
		EffectState.StatChanges.AddItem(Camaraderie);
	
	// Mobility

		Camaraderie.StatType = eStat_Mobility;
		Camaraderie.StatAmount = default.MOBILITY_BASE* int(EL);
		EffectState.StatChanges.AddItem(Camaraderie);

	//Defense
		Camaraderie.StatType = eStat_Defense;
		Camaraderie.StatAmount = default.DEFENSE_BASE* int(EL);
		EffectState.StatChanges.AddItem(Camaraderie);
	
	//Dodge

		Camaraderie.StatType = eStat_Dodge;
		Camaraderie.StatAmount = default.DODGE_BASE* int(EL);
		EffectState.StatChanges.AddItem(Camaraderie);

	// Hack

		Camaraderie.StatType = eStat_Hacking;
		Camaraderie.StatAmount = default.HACKING_BASE* int(EL);
		EffectState.StatChanges.AddItem(Camaraderie);
	
	// Armor

		Camaraderie.StatType = eStat_ArmorMitigation;
		Camaraderie.StatAmount = default.ARMOR_BASE* int(EL);
		EffectState.StatChanges.AddItem(Camaraderie);

	// Psi
	
		Camaraderie.StatType = eStat_PsiOffense;
		Camaraderie.StatAmount = default.PSI_BASE* int(EL);
		EffectState.StatChanges.AddItem(Camaraderie);
}

function bool IsEffectCurrentlyRelevant(XComGameState_Effect EffectGameState, XComGameState_Unit TargetUnit)
{
	//  Only relevant if we successfully rolled any stat changes
	return EffectGameState.StatChanges.Length > 0;
}

DefaultProperties
{
	EffectName = "Camaraderie"
	DuplicateResponse = eDupe_Ignore
}