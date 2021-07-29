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
var config array<name> arrAbilityList, arrAbilityListTemplars, arrAbilityListReapers, arrAbilityListSkirmishers;
var config array<name> arrExcludedAbility;
var config array<AbilityGrant> arrNoOfAbilities;
var config array<int> arrConditionSoldierDays;
var config float fRankScalar;
var config float fWillScalar;
var config bool bUseThisAbilityList;
var config array<float> arrComIntScalar;
var config float fAbilityChancePerEL;

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

static function GetAbilities(ECombatIntelligence ComInt, out array<name> Abilities, XComGameState_Unit UnitState, name Faction)
{
	local int i, NumberToRoll, RandRoll;
	local array<name> AbilitiesToRoll;
	local array<name> ClassTemplateAbilities;
	local name AbilityName;

	// Building the ability pool: Abilities from config
	if(default.bUseThisAbilityList && Faction != '')
	{
		if (Faction == 'Faction_Reapers')
		{
			foreach default.arrAbilityListReapers(AbilityName)
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

		else if (Faction == 'Faction_Skirmishers')
		{
			foreach default.arrAbilityListSkirmishers(AbilityName)
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

		else if (Faction == 'Faction_Templars')
		{
			foreach default.arrAbilityListTemplars(AbilityName)
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

// This version grants abilities from a common pool and should only add abilities if there is a squad leader on the mission. Called in FinalizeUnitAbilitiesForInit
static function GetAbilitiesForEL(float EL, out array<name> Abilities, XComGameState_Unit UnitState, name Faction)
{
	local int i, NumberToRoll, RandRoll, FractionalChance, NumAbilitiesAdded;
	local float NumAbilitiesAddedEL;
	local array<name> AbilitiesToRoll;
	local array<name> ClassTemplateAbilities;
	local name AbilityName;
	local ECombatIntelligence ComInt;

	// Building the ability pool: Abilities from config
	// For now, we use generic abilities not related to a faction leader
	if(Faction != '')
	{
		ComInt = UnitState.ComInt;
		foreach default.arrAbilityList(AbilityName)
		{			
			// Validate the abilities added via config
			// Can add EL specific restrictions later
			if(class'X2AbilityTemplateManager'.static.GetAbilityTemplateManager().FindAbilityTemplate(AbilityName) != none 
				&& AbilitiesToRoll.Find(AbilityName) < 1
				&& !HasAbilityInTree(UnitState, AbilityName))
			{
				AbilitiesToRoll.AddItem(AbilityName);
			}
		}

		// First we add abilities based on EL
		NumAbilitiesAddedEL = EL*default.fAbilityChancePerEL;

		// This handles the absolute/guranteed number added
		for(i = 0; i < int(NumAbilitiesAddedEL); i++)
		{
			NumberToRoll = AbilitiesToRoll.Length;
			RandRoll = `SYNC_RAND_STATIC(NumberToRoll);
			Abilities.AddItem(AbilitiesToRoll[RandRoll]);
			AbilitiesToRoll.Remove(RandRoll, 1);	
		}

		// For fractional chance
		FractionalChance = int(NumAbilitiesAddedEL%int(NumAbilitiesAddedEL));
		if (`SYNC_RAND_STATIC(100) < FractionalChance)
		{
			NumberToRoll = AbilitiesToRoll.Length;
			RandRoll = `SYNC_RAND_STATIC(NumberToRoll);
			Abilities.AddItem(AbilitiesToRoll[RandRoll]);
			AbilitiesToRoll.Remove(RandRoll, 1);
		}
		


		// Pull additional random abilities from the pool based on combat intelligence of the unit
		for(i = 0; i < default.arrNoOfAbilities[ComInt].Bonus; i++)
		{
			NumberToRoll = AbilitiesToRoll.Length;
			RandRoll = `SYNC_RAND_STATIC(NumberToRoll);
			Abilities.AddItem(AbilitiesToRoll[RandRoll]);
			AbilitiesToRoll.Remove(RandRoll, 1);
		}

		// If there is a chance to get additional ability based on higher combat int
		if(default.arrNoOfAbilities[ComInt].ChanceForAdditional > 0 && default.arrNoOfAbilities[ComInt].ChanceForAdditional > `SYNC_RAND_STATIC(100))
		{	
			// Uh.. this one a bit more optimised. Is it though? (Thor Ragnarok face...)
			Abilities.AddItem(AbilitiesToRoll[`SYNC_RAND_STATIC(AbilitiesToRoll.Length)]);
			AbilitiesToRoll.Remove(RandRoll, 1);	
		}
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

static function bool IsUnitALeader (StateObjectReference UnitRef, out name FactionName)
{
	local XComGameState_Unit Unit;
	Unit = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(UnitRef.ObjectID));

	if (Unit.IsResistanceHero())
	{
		FactionName = Unit.GetResistanceFaction().GetMyTemplateName();
		return true;
	}
		
	return false;

}

static function bool IsUnitASpecialist (XComGameState_Unit UnitState, out name FactionName)
{
	local UnitValue kUnitValue;

	UnitState.GetUnitValue('SBR_SpecialistTrainingFactionType',kUnitValue);
	if (kUnitValue.fValue > 0 && kUnitValue.fValue <= 1)
	{
		FactionName = 'Faction_Reapers';
		return true;
	}
	if (kUnitValue.fValue > 1 && kUnitValue.fValue <= 2)
	{
		FactionName = 'Faction_Skirmishers';
		return true;		
	}
	if (kUnitValue.fValue > 2 && kUnitValue.fValue <= 3)
	{
		FactionName = 'Faction_Templars';
		return true;		
	}
	
	return false;

}


static function float ReverseDifficultyScaling(float EL, int offset)
{
	/* 	if (EL > 0 && EL <= 5)
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
	} */

	local float m,c;
	local int CurrentForceLevel;

	CurrentForceLevel = class'UIUtilities_Strategy'.static.GetAlienHQ().ForceLevel;
	if (CurrentForceLevel > 0 && CurrentForceLevel <= 5)
	{
		EL += Max(0,offset);
	}
	else if (CurrentForceLevel > 5 && CurrentForceLevel <= 10)
	{
		EL += Max(0,offset-1);
	}
	else if (CurrentForceLevel > 10 && CurrentForceLevel <= 15)
	{
		EL += Max(0,offset-2);
	}
	else if (CurrentForceLevel > 15 && CurrentForceLevel <= 20)
	{
		EL += Max(0,offset-3);
	}
	else
	{
		EL = EL;
	}

	return EL;

}

static function int GetNumSpecialistAllowed()
{
	
	// Iterate over all soldiers in barracks and find out how many specialists we currently have
	local array<StateObjectReference> AllSoldierRefs;
	local StateObjectReference SoldierRef;
	local XComGameState_Unit Unit;
	local int currSpecialists[3];
	local int currTotalSpecialists, currFactionLeaders, NumAllowed;
	local name FactionName;

	AllSoldierRefs = GetAllSoldierRefs();

	foreach AllSoldierRefs(SoldierRef)
	{
		Unit = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(SoldierRef.ObjectID));
		if (IsUnitASpecialist(Unit, FactionName))
		{
			if (FactionName == 'Faction_Reapers')
			{	
				currSpecialists[0]+=1;
				currTotalSpecialists+=1;
			}
			else if (FactionName == 'Faction_Skirmishers')
			{	
				currSpecialists[1]+=1;
				currTotalSpecialists+=1;
			}
			else if (FactionName == 'Faction_Templars')
			{	
				currSpecialists[2]+=1;
				currTotalSpecialists+=1;
			}
		}

		if (Unit.IsResistanceHero())
			currFactionLeaders+=1;

	}

	// We allow 1 specialist per faction leader with squadsize/infil 1 upgrade, increasing to 2
	// We need a separate limit on how many can be deployed per mission and remove others' abilities
	NumAllowed = 0;
	
	// Depending on squad size upgrade or CI infil unlocks
	if ((`XCOMHQ.HasSoldierUnlockTemplate('InfiltrationSize2') || `XCOMHQ.HasSoldierUnlockTemplate('SquadSizeIIUnlock')))
		NumAllowed+=(2*currFactionLeaders);

	else if ((`XCOMHQ.HasSoldierUnlockTemplate('InfiltrationSize1') || `XCOMHQ.HasSoldierUnlockTemplate('SquadSizeI1Unlock')))
		NumAllowed+=(currFactionLeaders);

	return (NumAllowed - currTotalSpecialists);
}

static function int GetNumSpecialistsAllowedPerMission ()
{
	local int NumAllowed, currSpecs;
	local StateObjectReference UnitRef;
	local name FactionName;
	local array<int> IsSpecialist;

	// Depending on squad size upgrade or CI infil unlocks
	if ((`XCOMHQ.HasSoldierUnlockTemplate('InfiltrationSize2') || `XCOMHQ.HasSoldierUnlockTemplate('SquadSizeIIUnlock')))
		NumAllowed = 2;

	else if ((`XCOMHQ.HasSoldierUnlockTemplate('InfiltrationSize1') || `XCOMHQ.HasSoldierUnlockTemplate('SquadSizeI1Unlock')))
		NumAllowed = 1;

	else
		NumAllowed = 0;

	return NumAllowed;

}

static function int GetSpecialistsOnMission(array <StateObjectReference> SquadSoldiers, out array<int> IsSpecialist)
{
	local StateObjectReference UnitRef;
	local name FactionName;
	local int SpecsOnMission, i;
	
	for (i = 0; i < SquadSoldiers.Length; i++)
	{
		if (IsUnitASpecialist(XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(SquadSoldiers[i].ObjectID)),FactionName))
		{
			IsSpecialist.AddItem(i);
			SpecsOnMission+=1;
		}
	}

	return SpecsOnMission;
}

// To indicate the set of specialists that need to have their specilisation perks taken away
static function array<int> GetSpecialistsToBeCulled (array <StateObjectReference> SquadSoldiers, XComGameState_SBRSquad Squad)
{
	local StateObjectReference UnitRef, CommandingOfficerRef;
	local XComGameState_Unit UnitState;
	local XComGameState_ResistanceFaction FactionState;
	local name LeaderFactionName, SpecFactionName, SquadFactionName;
	local int LeadersOnMission,SpecsOnMission, AllowedSpecsOnMission, i;
	local array<int> SquadLeaderIdx, SpecialistsIdx;

	SquadFactionName = XComGameState_ResistanceFaction(`XCOMHISTORY.GetGameStateForObjectID(Squad.Faction.ObjectID)).GetMyTemplateName();
	foreach SquadSoldiers(UnitRef)
	{
		UnitState = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(UnitRef.ObjectID));
		if (IsUnitALeader(UnitRef, LeaderFactionName) && (SquadFactionName == LeaderFactionName))
		{
			SquadLeaderIdx.AddItem(1); // Correct Faction leader
			SpecialistsIdx.AddItem(0);
		}
		else if (IsUnitASpecialist(UnitState,SpecFactionName) && (SquadFactionName != SpecFactionName))
		{
			SpecialistsIdx.AddItem(1); // Wrong faction specialist
			SquadLeaderIdx.AddItem(0); 
		}
		else if (IsUnitASpecialist(UnitState,SpecFactionName) && (SquadFactionName == SpecFactionName))
		{
			SpecialistsIdx.AddItem(2); // Correct faction specialist
			SquadLeaderIdx.AddItem(0); 
		}
		else //Normal solider
		{
			SquadLeaderIdx.AddItem(0); 
			SpecialistsIdx.AddItem(0);
		}
	}

	// Only allow any specialists at all if we have at least one correct faction leader
	AllowedSpecsOnMission = 0;
	SpecsOnMission = 0;
	foreach SquadLeaderIdx(i)
	{
		if (SquadLeaderIdx[i] == 1)
		{
			AllowedSpecsOnMission = GetNumSpecialistsAllowedPerMission();
			break;
		}
	}

	// Do in order culling for now, not considering rank or will, etc. Maybe optimize later
	foreach SpecialistsIdx(i)
	{
		if (SpecialistsIdx[i] == 2)
		{
			SpecsOnMission += 1;
			if (SpecsOnMission > AllowedSpecsOnMission)
				SpecialistsIdx[i] = 1; // Set them to be culled
			else
				SpecialistsIdx[i] = 0; // Reset to normal
		}
			
	}

	return SpecialistsIdx;
}