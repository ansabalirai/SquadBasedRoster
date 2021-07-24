//---------------------------------------------------------------------------------------
//  FILE:    X2EventListener_Soldiers.uc
//  AUTHOR:  Rai
//  PURPOSE: This contains all the event listerners to override personnel status and populate screens and what not
//--
class X2EventListener_Soldiers extends X2EventListener config(LW_Overhaul);

var localized string OnLiaisonDuty;
var localized string OnInfiltrationMission;
var localized string UnitAlreadyInSquad;
var localized string UnitInSquad;
var localized string RankTooLow;
var localized string CannotModifyOnMissionSoldierTooltip;

static function array<X2DataTemplate> CreateTemplates()
{
	local array<X2DataTemplate> Templates;

	
	Templates.AddItem(CreateStatusListeners());


	return Templates;
}


static function CHEventListenerTemplate CreateStatusListeners()
{
	local CHEventListenerTemplate Template;

	`CREATE_X2TEMPLATE(class'CHEventListenerTemplate', Template, 'SoldierStatusListeners');
	Template.AddCHEvent('OverridePersonnelStatus', OnOverridePersonnelStatus, ELD_Immediate);

	Template.RegisterInStrategy = true;

	return Template;
}


// Sets the status string for liaisons and soldiers on missions.
static protected function EventListenerReturn OnOverridePersonnelStatus(Object EventData, Object EventSource, XComGameState NewGameState, Name InEventID, Object CallbackData)
{
	local XComLWTuple				OverrideTuple;
	local XComGameState_Unit		UnitState;
    local XComGameState_WorldRegion	WorldRegion;
	local XComGameState_SBRSquad Squad;
	local XComGameState_SBRSquadManager SquadMgr;
	local int						HoursToInfiltrate;
	local string 					StatusString;

	OverrideTuple = XComLWTuple(EventData);
	if (OverrideTuple == none)
	{
		`REDSCREEN("OverridePersonnelStatus event triggered with invalid event data.");
		return ELR_NoInterrupt;
	}

	UnitState = XComGameState_Unit(EventSource);
	if (UnitState == none)
	{
		`REDSCREEN("OverridePersonnelStatus event triggered with invalid source data.");
		return ELR_NoInterrupt;
	}

	if (OverrideTuple.Id != 'OverridePersonnelStatus')
	{
		return ELR_NoInterrupt;
	}

	SquadMgr = class'XComGameState_SBRSquadManager'.static.GetSquadManager();
	if (GetScreenOrChild('UIPersonnel_SquadBarracks') == none)
	{
		if (SquadMgr != none && SquadMgr.UnitIsInAnySquad(UnitState.GetReference(), Squad))
		{
			if (SquadMgr.LaunchingMissionSquad.ObjectID != Squad.ObjectID)
			{
				if (UnitState.GetStatus() != eStatus_Healing && UnitState.GetStatus() != eStatus_Training && UnitState.GetMentalState() != eMentalState_Shaken)
				{
					if (GetScreenOrChild('UISquadSelect') != none)
					{
						StatusString = default.UnitAlreadyInSquad;
						StatusString $= Squad.SquadName;
						SetStatusTupleData(OverrideTuple, StatusString , "", "", 0, eUIState_Warning, true);
					}
					// else if (GetScreenOrChild('UIPersonnel_Liaison') != none)
					// {
					// 	SetStatusTupleData(OverrideTuple, default.UnitInSquad, "", "", 0, eUIState_Warning, true);
					// }
				}
			}
		}
	}

	return ELR_NoInterrupt;
}

static private function UIScreen GetScreenOrChild(name ScreenType)
{
	local UIScreenStack ScreenStack;
	local int Index;
	ScreenStack = `SCREENSTACK;
	for( Index = 0; Index < ScreenStack.Screens.Length;  ++Index)
	{
		if(ScreenStack.Screens[Index].IsA(ScreenType))
			return ScreenStack.Screens[Index];
	}
	return none;
}

static private function SetStatusTupleData(
	XComLWTuple Tuple,
	string Status,
	string TimeLabel,
	string TimeValueOverride,
	int TimeValue,
	EUIState State,
	bool HideTime)
{
	Tuple.Data[0].s = Status;
	Tuple.Data[1].s = TimeLabel;
	Tuple.Data[2].s = TimeValueOverride;
	Tuple.Data[3].i = TimeValue;
	Tuple.Data[4].i = int(State);
	Tuple.Data[5].b = HideTime;
	Tuple.Data[6].b = TimeValueOverride == "";
}