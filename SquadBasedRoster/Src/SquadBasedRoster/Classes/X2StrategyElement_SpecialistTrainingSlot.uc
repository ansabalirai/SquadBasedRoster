//---------------------------------------------------------------------------------------
//  FILE:    X2StrategyElement_SpecialistTrainingSlot.uc
//  AUTHOR:  Rai
//  PURPOSE: Adds templates for specialist training staffslot for training in GTS
//---------------------------------------------------------------------------------------

class X2StrategyElement_SpecialistTrainingSlot extends X2StrategyElement_DefaultStaffSlots config(SquadBasedRoster);

var config array<name> arrExcludedClassesFromSlot;
var config array<name> arrPromotionClassesFromSlot;
var config int MininumRank;

//---------------------------------------------------------------------------------------
static function array<X2DataTemplate> CreateTemplates()
{
	local array<X2DataTemplate> StaffSlots;

	StaffSlots.AddItem(CreateSpecialistTrainingSlotTemplate());
		
	return StaffSlots;
}



static function X2DataTemplate CreateSpecialistTrainingSlotTemplate()
{
	local X2StaffSlotTemplate Template;
	local int i;

	Template = CreateStaffSlotTemplate('SBR_SpecialistTrainingSlot');
	Template.bSoldierSlot = true;
	Template.bRequireConfirmToEmpty = true;
	Template.bPreventFilledPopup = true;
	Template.UIStaffSlotClass = class'UIFacility_SpecialistTrainingSlot';
	Template.AssociatedProjectClass = class'XComGameState_HeadquartersProjectTrainSpecialist';
	Template.FillFn = SBR_ST_FillFn;
	Template.EmptyStopProjectFn = SBR_ST_EmptyStopProjectFn;
	Template.ShouldDisplayToDoWarningFn = SBR_ST_ShouldDisplayToDoWarningFn;
	Template.GetSkillDisplayStringFn = "";
	Template.GetBonusDisplayStringFn = SBR_ST_GetBonusDisplayStringFn;
	Template.IsUnitValidForSlotFn = SBR_ST_IsUnitValidForSlotFn;
	Template.MatineeSlotName = "Soldier";

	for (i = 0; i < default.arrExcludedClassesFromSlot.length; i++)
	{	
		Template.ExcludeClasses.AddItem(default.arrExcludedClassesFromSlot[i]);
	}
	
	return Template;
}




//---------------------------
// HELPERS FOR TRAINING SLOT-
//---------------------------
static function SBR_ST_FillFn(XComGameState NewGameState, StateObjectReference SlotRef, StaffUnitInfo UnitInfo, optional bool bTemporary = false)
{
	local XComGameState_Unit NewUnitState;
	local XComGameState_StaffSlot NewSlotState;
	local XComGameState_HeadquartersXCom NewXComHQ;	
	local XComGameState_HeadquartersProjectTrainSpecialist ProjectState;
	local StateObjectReference EmptyRef;
	local int SquadIndex;

	FillSlot(NewGameState, SlotRef, UnitInfo, NewSlotState, NewUnitState);
	NewXComHQ = GetNewXComHQState(NewGameState);	
	
	ProjectState = XComGameState_HeadquartersProjectTrainSpecialist(NewGameState.CreateNewStateObject(class'XComGameState_HeadquartersProjectTrainSpecialist'));
	ProjectState.SetProjectFocus(UnitInfo.UnitRef, NewGameState, NewSlotState.Facility);

	NewUnitState.SetStatus(eStatus_Training);
	NewXComHQ.Projects.AddItem(ProjectState.GetReference());

	// Remove their gear
	NewUnitState.MakeItemsAvailable(NewGameState, false);
	
	// If the unit undergoing training is in the squad, remove them
	SquadIndex = NewXComHQ.Squad.Find('ObjectID', UnitInfo.UnitRef.ObjectID);
	if (SquadIndex != INDEX_NONE)
	{
		// Remove them from the squad
		NewXComHQ.Squad[SquadIndex] = EmptyRef;
	}
}

static function SBR_ST_EmptyStopProjectFn(StateObjectReference SlotRef)
{
	local HeadquartersOrderInputContext OrderInput;
	local XComGameState_StaffSlot SlotState;
	local XComGameState_HeadquartersXCom XComHQ;
	local XComGameState_HeadquartersProjectTrainSpecialist ProjectState;	

	XComHQ = class'UIUtilities_Strategy'.static.GetXComHQ();
	SlotState = XComGameState_StaffSlot(`XCOMHISTORY.GetGameStateForObjectID(SlotRef.ObjectID));

	ProjectState = GetTrainProject(XComHQ, SlotState.GetAssignedStaffRef());	
	if (ProjectState != none)
	{		
		OrderInput.OrderType = eHeadquartersOrderType_CancelTrainRookie;
		OrderInput.AcquireObjectReference = ProjectState.GetReference();

		// class'XComGameStateContext_HeadquartersOrder'.static.IssueHeadquartersOrder(OrderInput);
		class'XComGameStateContext_HeadquartersOrderSBR'.static.IssueHeadquartersOrderSBR(OrderInput);
	}
}

static function bool SBR_ST_ShouldDisplayToDoWarningFn(StateObjectReference SlotRef)
{
	return false;
}

static function XComGameState_HeadquartersProjectTrainSpecialist GetTrainProject(XComGameState_HeadquartersXCom XComHQ, StateObjectReference UnitRef)
{
	local int idx;
	local XComGameState_HeadquartersProjectTrainSpecialist ProjectState;

	for (idx = 0; idx < XComHQ.Projects.Length; idx++)
	{
		ProjectState = XComGameState_HeadquartersProjectTrainSpecialist(`XCOMHISTORY.GetGameStateForObjectID(XComHQ.Projects[idx].ObjectID));

		if (ProjectState != none)
		{
			if (UnitRef == ProjectState.ProjectFocus)
			{
				return ProjectState;
			}
		}
	}

	return none;
}

static function string SBR_ST_GetBonusDisplayStringFn(XComGameState_StaffSlot SlotState, optional bool bPreview)
{
	local XComGameState_HeadquartersXCom XComHQ;
	local XComGameState_HeadquartersProjectTrainSpecialist ProjectState;
	local string Contribution;

	if (SlotState.IsSlotFilled())
	{
		XComHQ = class'UIUtilities_Strategy'.static.GetXComHQ();
		ProjectState = GetTrainProject(XComHQ, SlotState.GetAssignedStaffRef());

		if (ProjectState.GetTrainingClassTemplate().DisplayName != "")
			Contribution = Caps(ProjectState.GetTrainingClassTemplate().DisplayName);
		else
			Contribution = SlotState.GetMyTemplate().BonusDefaultText;
	}

	return GetBonusDisplayString(SlotState, "%SKILL", Contribution);
}

static function bool SBR_ST_IsUnitValidForSlotFn(XComGameState_StaffSlot SlotState, StaffUnitInfo UnitInfo)
{
	local XComGameState_Unit Unit;
	local UnitValue kUnitValue;
	local int EffectiveMinRank;

	Unit = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(UnitInfo.UnitRef.ObjectID));

	// Check unit value. This training is only allowed one time per soldier
	if(Unit.GetUnitValue('SBR_SpecialistTraining', kUnitValue))
	{
		if(kUnitValue.fValue > 0) return false;
	}


	EffectiveMinRank = (class'X2DownloadableContentInfo_SquadBasedRoster'.default.GO_CLASSLESS) ? 0 : 3;
	if (Unit.CanBeStaffed()
		&& Unit.IsSoldier()
		&& !Unit.IsResistanceHero() // For now, excluding faction heroes from this slot
		&& Unit.IsActive()
		&& Unit.GetRank() >= EffectiveMinRank
		&& SlotState.GetMyTemplate().ExcludeClasses.Find(Unit.GetSoldierClassTemplateName()) == INDEX_NONE // Certain classes can't retrain their abilities (Psi Ops)
		&& (class'X2Helper_SquadBasedRoster'.static.GetNumSpecialistAllowed() > 0)) // Limit on the total number of specialists trained
	{
		return true;
	}

	return false;
}