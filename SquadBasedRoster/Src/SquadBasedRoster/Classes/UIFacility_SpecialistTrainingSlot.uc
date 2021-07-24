//---------------------------------------------------------------------------------------
//  FILE:    UIFacility_SpecialistTrainingSlot.uc
//  AUTHOR:  Rai
//  PURPOSE: Adds UI support for displaying and selecting personnel list for the trainingslot
//---------------------------------------------------------------------------------------

class UIFacility_SpecialistTrainingSlot extends UIFacility_AcademySlot dependson(UIPersonnel);

var localized string m_strConditionSoldierDialogTitle;
var localized string m_strConditionSoldierDialogText;
var localized string m_strStopConditionSoldierDialogTitle;
var localized string m_strStopConditionSoldierDialogText;
var localized string m_strNoSoldiersTooltip;
var localized string m_strSoldiersAvailableTooltip;


//-----------------------------------------------------------------------------
simulated function ShowDropDown()
{
	local XComGameState_StaffSlot StaffSlot;
	local XComGameState_Unit UnitState;
	local string StopTrainingText;

	StaffSlot = XComGameState_StaffSlot(`XCOMHISTORY.GetGameStateForObjectID(StaffSlotRef.ObjectID));

	if (StaffSlot.IsSlotEmpty())
	{
		OnTrainingSelected();
		// StaffContainer.ShowDropDown(self);		
	}
	else // Ask the user to confirm that they want to empty the slot and stop training
	{		
		UnitState = StaffSlot.GetAssignedStaff();
		StopTrainingText = m_strStopConditionSoldierDialogText;
		StopTrainingText = Repl(StopTrainingText, "%UNITNAME", UnitState.GetName(eNameType_RankFull));		

		ConfirmEmptyProjectSlotPopup(m_strStopConditionSoldierDialogTitle, StopTrainingText);
	}
}

simulated function OnTrainingSelected()
{
	if(IsDisabled)
		return;

	ShowSoldierList(eUIAction_Accept, none);
}

simulated function ShowSoldierList(eUIAction eAction, UICallbackData xUserData)
{
	local UIPersonnel_SpecialistTraining kPersonnelList;
	local XComHQPresentationLayer HQPres;
	local XComGameState_StaffSlot StaffSlotState;
	
	if (eAction == eUIAction_Accept)
	{
		HQPres = `HQPRES;
		StaffSlotState = XComGameState_StaffSlot(`XCOMHISTORY.GetGameStateForObjectID(StaffSlotRef.ObjectID));

		//Don't allow clicking of Personnel List is active or if staffslot is filled
		if(HQPres.ScreenStack.IsNotInStack(class'UIPersonnel') && !StaffSlotState.IsSlotFilled())
		{
			kPersonnelList = Spawn( class'UIPersonnel_SpecialistTraining', HQPres);
			kPersonnelList.m_eListType = eUIPersonnel_Soldiers;
			kPersonnelList.onSelectedDelegate = OnSoldierSelected;
			kPersonnelList.m_bRemoveWhenUnitSelected = true;
			kPersonnelList.SlotRef = StaffSlotRef;
			HQPres.ScreenStack.Push( kPersonnelList );
		}
	}
}

// simulated function OnPersonnelSelected(StaffUnitInfo UnitInfo)
simulated function OnSoldierSelected(StateObjectReference UnitRef)
{
	local XComGameStateHistory History;	
	local XGParamTag LocTag;
	local TDialogueBoxData DialogData;
	local XComGameState_Unit Unit;
	local UICallbackData_StateObjectReference CallbackData;

	History = `XCOMHISTORY;
	// Unit = XComGameState_Unit(History.GetGameStateForObjectID(UnitInfo.UnitRef.ObjectID));	
	Unit = XComGameState_Unit(History.GetGameStateForObjectID(UnitRef.ObjectID));	

	LocTag = XGParamTag(`XEXPANDCONTEXT.FindTag("XGParam"));
	LocTag.StrValue0 = Unit.GetName(eNameType_RankFull);	
	// LocTag.StrValue1 = class'X2ExperienceConfig'.static.GetRankName(Unit.GetSoldierRank(), '');

	CallbackData = new class'UICallbackData_StateObjectReference';
	CallbackData.ObjectRef = Unit.GetReference();
	DialogData.xUserData = CallbackData;
	DialogData.fnCallbackEx = TrainSpecialistDialogCallback;

	DialogData.eType = eDialog_Alert;
	DialogData.strTitle = m_strConditionSoldierDialogTitle;
	DialogData.strText = `XEXPAND.ExpandString(m_strConditionSoldierDialogText);
	DialogData.strAccept = class'UIUtilities_Text'.default.m_strGenericYes;
	DialogData.strCancel = class'UIUtilities_Text'.default.m_strGenericNo;

	Movie.Pres.UIRaiseDialog(DialogData);
}

simulated function TrainSpecialistDialogCallback(Name eAction, UICallbackData xUserData)
{
	local UICallbackData_StateObjectReference CallbackData;
	local XComHQPresentationLayer HQPres;
	local UIChooseClass_TrainSpecialist ChooseClassScreen;	
		
	CallbackData = UICallbackData_StateObjectReference(xUserData);
	
	if (eAction == 'eUIAction_Accept')
	{				
		HQPres = `HQPRES;		

		if (HQPres.ScreenStack.IsNotInStack(class'UIChooseClass_TrainSpecialist'))
		{
			ChooseClassScreen = Spawn(class'UIChooseClass_TrainSpecialist', self);			
			ChooseClassScreen.m_UnitRef = CallbackData.ObjectRef;
			HQPres.ScreenStack.Push(ChooseClassScreen);
		}
	}
}