class XComPresentationLayer_SBR extends XComHQPresentationLayer;


static function UITrainingCompleteSpecialist(StateObjectReference UnitRef, X2AbilityTemplate AbilityTemplate, string ExtraInfo)
{
	local DynamicPropertySet PropertySet;

	BuildUIAlert(PropertySet, 'eAlert_TrainingComplete', TrainingCompleteCB, '', "Geoscape_CrewMemberLevelledUp", true);
	class'X2StrategyGameRulesetDataStructures'.static.AddDynamicIntProperty(PropertySet, 'UnitRef', UnitRef.ObjectID);
    class'X2StrategyGameRulesetDataStructures'.static.AddDynamicNameProperty(PropertySet, 'AbilityTemplate', AbilityTemplate.DataName);
    class'X2StrategyGameRulesetDataStructures'.static.AddDynamicStringProperty(PropertySet, 'ExtraInfo', ExtraInfo);     
	QueueDynamicPopup(PropertySet);
}

static function BuildUIAlert(
	out DynamicPropertySet PropertySet, 
	Name AlertName, 
	delegate<X2StrategyGameRulesetDataStructures.AlertCallback> CallbackFunction, 
	Name EventToTrigger, 
	string SoundToPlay,
	bool bImmediateDisplay = true)
{	
    class'X2StrategyGameRulesetDataStructures'.static.BuildDynamicPropertySet(PropertySet, 'UIAlert_TrainSpecialist', AlertName, CallbackFunction, bImmediateDisplay, true, true, false);
	class'X2StrategyGameRulesetDataStructures'.static.AddDynamicNameProperty(PropertySet, 'EventToTrigger', EventToTrigger);
	class'X2StrategyGameRulesetDataStructures'.static.AddDynamicStringProperty(PropertySet, 'SoundToPlay', SoundToPlay);
}

simulated function TrainingCompleteCB(Name eAction, out DynamicPropertySet AlertData, optional bool bInstant = false)
{
	local XComGameState NewGameState;
	local XComGameState_Unit UnitState;
	
	if( eAction == 'eUIAction_Accept' || eAction == 'eUIAction_Cancel' )
	{
		// Flag the new class popup as having been seen
		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Unit Promotion Callback");
		UnitState = XComGameState_Unit(NewGameState.ModifyStateObject(class'XComGameState_Unit',
																	  class'X2StrategyGameRulesetDataStructures'.static.GetDynamicIntProperty(AlertData, 'UnitRef')));
		UnitState.bNeedsNewClassPopup = false;
		`XEVENTMGR.TriggerEvent('UnitPromoted', , , NewGameState);
		`GAMERULES.SubmitGameState(NewGameState);

        if( eAction == 'eUIAction_Cancel' )
        {
            GoToOfficerTrainingSchool();
        }
	}
}

simulated function GoToOfficerTrainingSchool()
{
	local XComGameState_HeadquartersXCom XComHQ;
	local XComGameState_FacilityXCom FacilityState;
	
	if (`GAME.GetGeoscape().IsScanning())
		StrategyMap2D.ToggleScan();

	XComHQ = class'UIUtilities_Strategy'.static.GetXComHQ();
	FacilityState = XComHQ.GetFacilityByName('OfficerTrainingSchool');
	FacilityState.GetMyTemplate().SelectFacilityFn(FacilityState.GetReference(), true);
}