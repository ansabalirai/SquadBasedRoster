//---------------------------------------------------------------------------------------
//  FILE:    XComGameState_Unit_SBRSpecialist.uc
//  AUTHOR:  Rai 
//  PURPOSE: This is a component extension for Unit GameStates, containing 
//				additional data used for squad sepcialists.
//---------------------------------------------------------------------------------------
class XComGameState_Unit_SBRSpecialist extends XComGameState_BaseObject config(SquadBasedRoster);

struct LeadershipEntry
{
	var StateObjectReference UnitRef;
	var int SuccessfulMissionCount;
};

// For specialists, maybe add abilities from a specific pool depending on affinity to a faction and rank?
var StateObjectReference AssignedFactionRef;
var name FactionName; // Likely point to the FactionName in XComGameState_ResistanceFaction when promoted

var StateObjectReference CurrentAssignedSquad;

var array<ClassAgnosticAbility>	SpecialistAbilities;

var int SpecialistRank;
var int CurrentRank; // Can be different from SpecialistRank if they are assigned to a factionless squad
var protected array<int> MissionsAtRank;
var protected int RankTraining;
var name AbilityTrainingName;
var name LastAbilityTrainedName;

var array<LeadershipEntry> LeadershipData;




/////////////////////////////////////////////////////////////
// ToDO: Make sure to add this component to the specialists when they are initially trained
// Either in a tube in GTS/Training center or an instant levelup after certain rank/mission requirement are met
function XComGameState_Unit_SBRSpecialist InitComponent(optional StateObjectReference FactionRef)
{
	SpecialistRank = 0;
	//AssignedFactionRef = FactionRef;
	RegisterSoldierTacticalToStrategy();

	// To Do: Change rank names, assign a faction and show a pop up that this unit is not being permamently assigned to 
	// a certain faction. Input can be the current squad?

	return self;
}




////////////////////////////////////////////////////////////////////////////
// HELPERS---------------------------------------------------------
// Returns the specialist component attached to the supplied Unit GameState
static function XComGameState_Unit_SBRSpecialist GetSpecialistComponent(XComGameState_Unit Unit)
{
	if (Unit != none) 
		return XComGameState_Unit_SBRSpecialist(Unit.FindComponentObject(class'XComGameState_Unit_SBRSpecialist'));
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
	local XComGameState_Unit_SBRSpecialist SpecialistState;

	Unit = XComGameState_Unit(EventData);

	//check we have the right unit
	if(Unit.ObjectID != OwningObjectID)
		return ELR_NoInterrupt;

	//find officer state component for change state on unit
	SpecialistState = GetSpecialistComponent(Unit);
	if (SpecialistState == none) 
	{
		//`Redscreen("Failed to find Officer State Component when updating officer mission count : SoldierTacticalToStrategy");
		return ELR_NoInterrupt;
	}

	//create gamestate delta for specialist component
	SpecialistState = XComGameState_Unit_SBRSpecialist(GameState.CreateStateObject(class'XComGameState_Unit_SBRSpecialist', SpecialistState.ObjectID));

	//To DO: Add +1 mission complete to current specialist data
	//SpecialistState.AddMission();

	//add officer component gamestate delta to change container from triggered event 
	GameState.AddStateObject(SpecialistState);

	return ELR_NoInterrupt;
}