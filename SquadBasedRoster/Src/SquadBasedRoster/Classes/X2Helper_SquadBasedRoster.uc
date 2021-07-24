//---------------------------------------------------------------------------------------
//  AUTHOR:  Rai
//  PURPOSE: Houses various common functionality used in various places by this mod
//---------------------------------------------------------------------------------------
//  Copied from WOTCStrategyOverhaul Team
//---------------------------------------------------------------------------------------

class X2Helper_SquadBasedRoster extends Object abstract;



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

