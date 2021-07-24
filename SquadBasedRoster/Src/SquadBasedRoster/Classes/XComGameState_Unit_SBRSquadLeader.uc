//---------------------------------------------------------------------------------------
//  FILE:    XComGameState_Unit_SBRSquadLeader.uc
//  AUTHOR:  Rai 
//  PURPOSE: This is a component extension for Unit GameStates, containing 
//				additional data used for squad leaders.
//---------------------------------------------------------------------------------------
class XComGameState_Unit_SBRSquadLeader extends XComGameState_BaseObject config(SquadBasedRoster);

struct LeadershipEntry
{
	var StateObjectReference UnitRef;
	var int SuccessfulMissionCount;
};

var array<ClassAgnosticAbility>	SquadLeaderAbilities;

// For leaders, there is no ranking up as of now. Might add something later
var protected int LeaderRank;
var protected array<int> MissionsAtRank;
var protected int RankTraining;
var name AbilityTrainingName;
var name LastAbilityTrainedName;

var array<LeadershipEntry> LeadershipData;







/////////////////////////////////////////////////////////////
// ToDO: Make sure to add this component to the leaders when they are initially acquired, i.e. when added to barracks
function XComGameState_Unit_SBRSquadLeader InitComponent()
{
	LeaderRank = 0;
	RegisterSoldierTacticalToStrategy();
	return self;
}



///////////////////////////////////////////////////////////////////////
// ------------------ LEADERSHIP ------------------

// assumes that the Officer component is already added to supplied NewGameState
function AddSuccessfulMissionToLeaderShip(StateObjectReference UnitRef, XComGameState NewGameState, optional int Count = 1)
{
	local int idx;
	local LeadershipEntry Entry, EmptyEntry;
	local bool bFoundExistingUnit;

	foreach LeadershipData(Entry, idx)
	{
		if (Entry.UnitRef.ObjectID == UnitRef.ObjectID)
		{
			bFoundExistingUnit = true;
			break;
		}
	}
	if (bFoundExistingUnit)
	{
		LeadershipData[idx].SuccessfulMissionCount += Count;
	}
	else
	{
		Entry = EmptyEntry;
		Entry.UnitRef = UnitRef;
		Entry.SuccessfulMissionCount = Count;
		LeadershipData.AddItem(Entry);
	}
}

////////////////////////////////////////////////////////////////////////////
// HELPERS---------------------------------------------------------
// Returns the leader component attached to the supplied Unit GameState
static function XComGameState_Unit_SBRSquadLeader GetLeaderComponent(XComGameState_Unit Unit)
{
	if (Unit != none) 
		return XComGameState_Unit_SBRSquadLeader(Unit.FindComponentObject(class'XComGameState_Unit_SBRSquadLeader'));
	return none;
}





////////////////////////////////////////////////////////////////////////////
// EVENT HANDLING---------------------------------------------------------

function RegisterSoldierTacticalToStrategy()
{
	local Object ThisObj;
	
	ThisObj = self;

	//this should function for SimCombat as well
	`XEVENTMGR.RegisterForEvent(ThisObj, 'SoldierTacticalToStrategy', OnSoldierTacticalToStrategy, ELD_OnStateSubmitted,,, true);
}

simulated function EventListenerReturn OnSoldierTacticalToStrategy(Object EventData, Object EventSource, XComGameState GameState, Name InEventID, Object CallbackData)
{
	local XComGameState_Unit Unit;
	local XComGameState_Unit_SBRSquadLeader OfficerState;

	Unit = XComGameState_Unit(EventData);

	//check we have the right unit
	if(Unit.ObjectID != OwningObjectID)
		return ELR_NoInterrupt;

	//find officer state component for change state on unit
	OfficerState = GetLeaderComponent(Unit);
	if (OfficerState == none) 
	{
		//`Redscreen("Failed to find Officer State Component when updating officer mission count : SoldierTacticalToStrategy");
		return ELR_NoInterrupt;
	}

	//create gamestate delta for officer component
	OfficerState = XComGameState_Unit_SBRSquadLeader(GameState.CreateStateObject(class'XComGameState_Unit_SBRSquadLeader', OfficerState.ObjectID));

	//To DO: Add +1 mission complete to current leader data
	//OfficerState.AddMission();

	//add officer component gamestate delta to change container from triggered event 
	GameState.AddStateObject(OfficerState);

	return ELR_NoInterrupt;
}