//---------------------------------------------------------------------------------------
//  AUTHOR:  Rai
//  PURPOSE: Houses various common functionality used in various places by this mod
//---------------------------------------------------------------------------------------
//  Copied from WOTCStrategyOverhaul Team
//---------------------------------------------------------------------------------------

class X2Helper_SquadBasedRoster extends Object config(SquadBasedRoster);

struct AbilityGrant
{
	var int Bonus;
	var int ChanceForAdditional;
};

var config array<int> arrComIntBonus;
var config array<name> arrAbilityList;
var config array<name> arrExcludedAbility;
var config array<AbilityGrant> arrNoOfAbilities;
var config array<int> arrConditionSoldierDays;
var config float fRankScalar;
var config float fWillScalar;
var config bool bUseThisAbilityList;
var config array<float> arrComIntScalar;

/* Probably can be used if we build against CI to get the mission site from covert action site directly to assign to a specific squad
static function XComGameState_MissionSite GetMissionSiteFromAction (XComGameState_CovertAction Action)
{
	local XComGameState_MissionSite MissionSite;
	local XComGameState_Activity ActivityState;

	ActivityState = class'XComGameState_Activity'.static.GetActivityFromSecondaryObject(Action);
	
	if (ActivityState != none)
	{
		MissionSite = GetMissionStateFromActivity(ActivityState);
	}

	return MissionSite;
}*/


// Note that we add directly to state instead of returning the array so that the MeetsRequirements call later accounts for this sitrep
static function ApplySBRSitreps (XComGameState_MissionSite MissionState)
{
	local array<name> EnviromentalSitreps, AllSitReps;
	local X2SitRepTemplateManager SitRepMgr;
	local X2SitRepTemplate SitRepTemplate;
	local int MaxNumSitReps, NumSelected;
	local array<string> SitRepCards;
	local X2CardManager CardMgr;
	local string sSitRep;
	local name nSitRep;
    local name RapidFire;


	SitRepMgr = class'X2SitRepTemplateManager'.static.GetSitRepTemplateManager();
	CardMgr = class'X2CardManager'.static.GetCardManager();
	
	CardMgr.AddCardToDeck('SitReps', string(nSitRep));
	

	// Get all of the currently existing sitreps
	// This is used to prevent redscreens from FindSitRepTemplate due to old cards in the deck
	SitRepMgr.GetTemplateNames(AllSitReps);


    foreach AllSitReps(nSitrep)
    {
        `Log('SitRepTemplateName is ' $nSitRep );
    }
    SitRepTemplate = SitRepMgr.FindSitRepTemplate('RapidFireEffect');
    if (SitRepTemplate != none)
        MissionState.GeneratedMission.SitReps.AddItem(SitRepTemplate.DataName);

    return;
	// Select the sitreps until we fill out the array (or run out of candidates)
	CardMgr.GetAllCardsInDeck('SitReps', SitRepCards);
    

    EnviromentalSitreps.AddItem('RapidFireEffect');
    EnviromentalSitreps.AddItem('Foxholes');
	foreach SitRepCards(sSitRep)
	{
		nSitRep = name(sSitRep);
		`Log('SitRepCarName is ' $nSitRep );
		// Redscreen prevention
		if (AllSitReps.Find(nSitRep) == INDEX_NONE) continue;

		// Actual fetch
		SitRepTemplate = SitRepMgr.FindSitRepTemplate(nSitRep);
        `Log('SitRepTemplateName is' $SitRepTemplate.DataName );

		if (SitRepTemplate != none &&
			EnviromentalSitreps.Find(SitRepTemplate.DataName) != INDEX_NONE
            )
		{
			MissionState.GeneratedMission.SitReps.AddItem(SitRepTemplate.DataName);
			CardMgr.MarkCardUsed('SitReps', sSitRep);
		}
	}
}



static function array<StateObjectReference> GetAllSoldierRefs()
{
	local XComGameState_HeadquartersXCom XComHQ;
	local array<StateObjectReference> OutRef, NullRef;
	local XComGameState_Unit UnitState;
	local int idx;

	XComHQ = `XCOMHQ;
	if (XComHQ == none)
		return NullRef;

	for (idx = 0; idx < XComHQ.Crew.Length; idx++)
	{
		if (XComHQ.Crew[idx].ObjectID > 0)
		{
			UnitState = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(XComHQ.Crew[idx].ObjectID));
			if(UnitState != none && UnitState.IsSoldier())
				OutRef. AddItem(XComHQ.Crew[idx]);
		}			

	}
	return OutRef;

}



static function array<StateObjectReference> GetAllSoldierRefsNotOnMission()
{
	local XComGameState_HeadquartersXCom XComHQ;
	local array<StateObjectReference> OutRef, NullRef;
	local StateObjectReference InRef;
	local XComGameState_Unit UnitState;
	local int idx;

	XComHQ = `XCOMHQ;
	if (XComHQ == none)
		return NullRef;

	for (idx = 0; idx < XComHQ.Crew.Length; idx++)
	{
		if (XComHQ.Crew[idx].ObjectID > 0)
		{
			UnitState = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(XComHQ.Crew[idx].ObjectID));
			if(UnitState != none && UnitState.IsSoldier())
			{
				InRef = XComHQ.Crew[idx];
				if (XComHQ.Squad.Find('ObjectID', InRef.ObjectID) == -1)
					OutRef.AddItem(InRef);
			}
			
		}			

	}
	return OutRef;

}


static function string TruncFloat(float v, int Places)
{
    local int Whole;
    local string Dec;
    
    Whole = int(v);  // gets the stuff to the left of the decimal point
    Dec = Left(Split(string(v), ".", true), Places);  // gets a certain number of digits (Places) to the right of the decimal point

    if (Places > 0)
        return string(Whole)$"."$Dec;  // returns the result of gluing Whole and Dec together on either side of a decimal point
    else
        return string(Whole);         //returns only the Dec part of the number
}

//---------------------------------------------------------------------------------------
//  Adding helper fumctions for specialist training slot
//---------------------------------------------------------------------------------------
static function AddSlotToExistingFacility(name SlotTemplateName, name FacilityName)
{
	local XComGameState_HeadquartersXCom XComHQ;
	local XComGameState_FacilityXCom FacilityState;
	local XComGameState_StaffSlot StaffSlotState, StaffSlotStateExisting;
	local XComGameState NewGameState;
	local X2StaffSlotTemplate StaffSlotTemplate;
	local int i;	
	local bool bHasSlot;
	local X2StrategyElementTemplateManager StratMgr;	
	
	`LOG("SBR: Attempting to update built facility");

	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("SBR Specialist Training -- Adding New Slot");	

	XComHQ = XComGameState_HeadquartersXCom(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersXCom'));
	StratMgr = class'X2StrategyElementTemplateManager'.static.GetStrategyElementTemplateManager();

	FacilityState = XComHQ.GetFacilityByName(FacilityName);

	if (FacilityState != none)
	{
		FacilityState = XComGameState_FacilityXCom(NewGameState.ModifyStateObject(class'XComGameState_FacilityXCom', FacilityState.ObjectID));

		bHasSlot = false;
		for ( i = 0; i < FacilityState.StaffSlots.length; i++)
		{
			StaffSlotStateExisting = XComGameState_StaffSlot(`XCOMHISTORY.GetGameStateForObjectID(FacilityState.StaffSlots[i].ObjectID));
			if ( StaffSlotStateExisting.GetMyTemplateName() == SlotTemplateName )
			{
				bHasSlot = true;
				break;
			}
		}

		if (!bHasSlot)
		{
			StaffSlotTemplate = X2StaffSlotTemplate(StratMgr.FindStrategyElementTemplate(SlotTemplateName));
			StaffSlotState = StaffSlotTemplate.CreateInstanceFromTemplate(NewGameState);
			StaffSlotState.UnlockSlot();
			StaffSlotState.Facility = FacilityState.GetReference();

			FacilityState.StaffSlots.AddItem(StaffSlotState.GetReference());

			`GAMERULES.SubmitGameState(NewGameState);	
		}
		else 
		{ 
			`XCOMHISTORY.CleanupPendingGameState(NewGameState);
		}
		
	}
	else
	{
		`XCOMHISTORY.CleanupPendingGameState(NewGameState);
	}
}


static function AddSlotToFacility(name Facility, name StaffSlot, optional bool StartsLocked = true)//, optional int i = -1)
{
	local X2StrategyElementTemplateManager TemplateManager;
	local X2FacilityTemplate FacilityTemplate;
	local StaffSlotDefinition StaffSlotDef;	
	local int j;
	local array<X2DataTemplate>	 DataTemplates;	

	TemplateManager = class'X2StrategyElementTemplateManager'.static.GetStrategyElementTemplateManager();
	//FacilityTemplate = X2FacilityTemplate(TemplateManager.FindStrategyElementTemplate(Facility));	

	TemplateManager.FindDataTemplateAllDifficulties(Facility, DataTemplates);

	StaffSlotDef.StaffSlotTemplateName = StaffSlot;
	StaffSlotDef.bStartsLocked = StartsLocked;

	for ( j = 0; j < DataTemplates.Length; j++ )
	{
		FacilityTemplate = X2FacilityTemplate(DataTemplates[j]);
		if ( FacilityTemplate != none )
		{
			if ( FacilityTemplate.StaffSlotDefs.find('StaffSlotTemplateName', StaffSlot) == INDEX_NONE )
			{
				FacilityTemplate.StaffSlotDefs.AddItem(StaffSlotDef);
			}
			else
			{
			}

			// This prevents idle staff message from showing up when they are staffed into this new slot
			FacilityTemplate.IsFacilityProjectActiveFn = IsRecoveryCenterProjectActiveOverride;
		}
	}
}

static function bool IsRecoveryCenterProjectActiveOverride(StateObjectReference FacilityRef)
{
	local XComGameStateHistory History;	
	local XComGameState_FacilityXCom FacilityState;
	local XComGameState_StaffSlot StaffSlot;	
	local int i;

	History = `XCOMHISTORY;	
	FacilityState = XComGameState_FacilityXCom(History.GetGameStateForObjectID(FacilityRef.ObjectID));
	
	for (i = 0; i < FacilityState.StaffSlots.Length; i++)
	{
		StaffSlot = FacilityState.GetStaffSlot(i);
		// Special handling: If its our slot, just pretend that there is an active project
		if (StaffSlot.IsSlotFilled() && StaffSlot.GetMyTemplateName() == 'SBR_SpecialistTrainingSlot')
		{
			return true;
		}
	}
	// Then we call the legacy method for compatibility with other mods
	return class'X2StrategyElement_XpackFacilities'.static.IsRecoveryCenterProjectActive(FacilityRef);
}

/*
static function int RollBonus(ECombatIntelligence ComInt, StatRanges Range)
{
    local int RandRoll, Bonus, Plus, PartBonus;
    local float Percent, ImprovedRoll;

    RandRoll = `SYNC_RAND_STATIC(100);
    ImprovedRoll = RandRoll + default.arrComIntBonus[ComInt];

    if(ImprovedRoll > 100) ImprovedRoll = 100;

    Plus = Range.MaxBonus - Range.MinBonus + 1;
    Percent = ImprovedRoll/100.0;
    PartBonus = Round(Plus * Percent);
    Bonus = PartBonus + Range.MinBonus - 1;

    if(Bonus < 1) Bonus = 1;

    `LOG("RandRoll:" @RandRoll, default.bEnableLog, 'WOTC_SolderConditioning');
    `LOG("ImprovedRoll:" @ImprovedRoll, default.bEnableLog, 'WOTC_SolderConditioning');
    `LOG("Plus:" @Plus, default.bEnableLog, 'WOTC_SolderConditioning');
    `LOG("Percent:" @Percent, default.bEnableLog, 'WOTC_SolderConditioning');
    `LOG("PartBonus:" @PartBonus, default.bEnableLog, 'WOTC_SolderConditioning');

    return Bonus;
}

static function int GiveAbilityPoints(ECombatIntelligence ComInt)
{
	local int RandRoll, Plus, PartBonus, Bonus;
	local float Percent;

	RandRoll = `SYNC_RAND_STATIC(100);
	Percent = RandRoll/100.0;
	Plus = default.arrAbilityPointRange[ComInt].MaxBonus - default.arrAbilityPointRange[ComInt].MinBonus + 1;
	PartBonus = Round(Plus * Percent);
	Bonus = PartBonus + default.arrAbilityPointRange[ComInt].MinBonus - 1;

	if(Bonus < 1) Bonus = 1;

    `LOG("RandRoll:" @RandRoll, default.bEnableLog, 'WOTC_SolderConditioning');    
    `LOG("Plus:" @Plus, default.bEnableLog, 'WOTC_SolderConditioning');
    `LOG("Percent:" @Percent, default.bEnableLog, 'WOTC_SolderConditioning');
    `LOG("PartBonus:" @PartBonus, default.bEnableLog, 'WOTC_SolderConditioning');

	return Bonus;
} */

static function GetAbilities(ECombatIntelligence ComInt, out array<name> Abilities, XComGameState_Unit UnitState)
{
	local int i, NumberToRoll, RandRoll;
	local array<name> AbilitiesToRoll;
	local array<name> ClassTemplateAbilities;
	local name AbilityName;

	// if(default.bUseThisAbilityList) AbilitiesToRoll = default.arrAbilityList;

	// Building the ability pool: Abilities from config
	if(default.bUseThisAbilityList)
	{
		foreach default.arrAbilityList(AbilityName)
		{			
			// Validate the abilities added via config
			if(class'X2AbilityTemplateManager'.static.GetAbilityTemplateManager().FindAbilityTemplate(AbilityName) != none 
				&& AbilitiesToRoll.Find(AbilityName) < 1
				&& !HasAbilityInTree(UnitState, AbilityName))
			{
				AbilitiesToRoll.AddItem(AbilityName);
			}
		}
	}

	// Building the ability pool: Abilities from class template: either from random deck or from AWC depending on class template
	//GetClassTemplateAbilities(UnitState, ClassTemplateAbilities);

	for(i = 0; i < ClassTemplateAbilities.Length; i++)
	{
		if(AbilitiesToRoll.find(ClassTemplateAbilities[i]) < 0)
		{
			AbilitiesToRoll.AddItem(ClassTemplateAbilities[i]);
		}
	}

	// Pull random abilities from the pool
	for(i = 0; i < default.arrNoOfAbilities[ComInt].Bonus; i++)
	{
		NumberToRoll = AbilitiesToRoll.Length;
		RandRoll = `SYNC_RAND_STATIC(NumberToRoll);
		Abilities.AddItem(AbilitiesToRoll[RandRoll]);
		AbilitiesToRoll.Remove(RandRoll, 1);
	}

	// If there is a chance to get additional ability
	if(default.arrNoOfAbilities[ComInt].ChanceForAdditional > 0 && default.arrNoOfAbilities[ComInt].ChanceForAdditional > `SYNC_RAND_STATIC(100))
	{	
		// Uh.. this one a bit more optimised
		Abilities.AddItem(AbilitiesToRoll[`SYNC_RAND_STATIC(AbilitiesToRoll.Length)]);
		AbilitiesToRoll.Remove(RandRoll, 1);	
	}
}

/*
static function GetClassTemplateAbilities(XComGameState_Unit UnitState, out array<name> ClassTemplateAbilities)
{	
	local array<SoldierClassAbilityType> CrossClassAbilities;
	local SoldierClassAbilityType stCrossClassAbilities;	
	local SoldierClassRandomAbilityDeck RandomDeck;	
	
	CrossClassAbilities = class'X2SoldierClassTemplateManager'.static.GetSoldierClassTemplateManager().GetCrossClassAbilities_CH(UnitState.AbilityTree);

	if(class'CHHelpers'.default.ClassesExcludedFromAWCRoll.Find(UnitState.GetSoldierClassTemplateName()) == INDEX_NONE)
	{
		foreach CrossClassAbilities(stCrossClassAbilities)
		{		
			if(!HasAbilityInTree(UnitState, stCrossClassAbilities.AbilityName) && default.arrExcludedAbility.Find(stCrossClassAbilities.AbilityName) == INDEX_NONE
				&& class'X2AbilityTemplateManager'.static.GetAbilityTemplateManager().FindAbilityTemplate(stCrossClassAbilities.AbilityName) != none)
			{
				ClassTemplateAbilities.AddItem(stCrossClassAbilities.AbilityName);
				`LOG("Added AWC ability:" @stCrossClassAbilities.AbilityName, default.bEnableLog, 'WOTC_SolderConditioning');
			}
		}
	}
	else
	{
		foreach UnitState.GetSoldierClassTemplate().RandomAbilityDecks(RandomDeck)
		{
			foreach RandomDeck.Abilities(stCrossClassAbilities)
			{
				if(!HasAbilityInTree(UnitState, stCrossClassAbilities.AbilityName) && default.arrExcludedAbility.Find(stCrossClassAbilities.AbilityName) == INDEX_NONE
					&& class'X2AbilityTemplateManager'.static.GetAbilityTemplateManager().FindAbilityTemplate(stCrossClassAbilities.AbilityName) != none)
				{					
					ClassTemplateAbilities.AddItem(stCrossClassAbilities.AbilityName);
					`LOG("Added Random Deck ability:" @stCrossClassAbilities.AbilityName, default.bEnableLog, 'WOTC_SolderConditioning');
				}
			}
		}		
	}
} */



static function int GetTrainingDays(XComGameState_Unit UnitState)
{
	local int BaseDays, SoldierRank, DaysByRank, DaysFinal;
	local ECombatIntelligence ComInt;

	BaseDays = `ScaleStrategyArrayInt(default.arrConditionSoldierDays);
	SoldierRank = UnitState.GetSoldierRank();
	ComInt = UnitState.ComInt;

	// if(SoldierRank == 1) DaysByRank = BaseDays;
	// if(SoldierRank == class'X2StrategyElement_ConditionSoldierSlot'.default.MininumRank) DaysByRank = BaseDays;
	// else
	// {
	DaysByRank = round(BaseDays * default.fRankScalar * SoldierRank);
	if(DaysByRank < BaseDays) DaysByRank = BaseDays;	// Don't go lower than config
	// }

	// if(ComInt == 0) DaysFinal = DaysByRank;
	// else
	// {
	// 	DaysFinal = DaysByRank - (default.fComIntScalar * ComInt);
	// 	`LOG("DaysFinal:" @DaysFinal, default.bEnableLog, 'WOTC_SolderConditioning');
	// }
	DaysFinal = DaysByRank - round(DaysByRank * default.arrComIntScalar[ComInt]);

	return DaysFinal;
}

static function bool HasAbilityInTree(XComGameState_Unit UnitState, name AbilityName)
{
	local SoldierRankAbilities Abilities;
	local SoldierClassAbilityType Ability;

	foreach UnitState.AbilityTree(Abilities)
	{
		foreach Abilities.Abilities(Ability)
		{
			if(Ability.AbilityName == AbilityName)
			{
				return true;
			}
		}
	}
	return false;
}