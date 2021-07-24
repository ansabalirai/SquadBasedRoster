//---------------------------------------------------------------------------------------
//  FILE:    UIAlert_TrainSpecialist.uc
//  AUTHOR:  Rai
//  PURPOSE: Adds ?
//---------------------------------------------------------------------------------------
class UIAlert_TrainSpecialist extends UIAlert;

var localized string m_strContinueCSTraining;
var localized string m_strBonusCS;

//---------------------------------------------------------------------------------------
simulated function BuildAlert()
{    
	BindLibraryItem();

	switch( eAlertName )
	{
	case 'eAlert_TrainingComplete':
		BuildConditionTrainingCompleteAlert(m_strTrainingCompleteLabel);
		break;

	default:
		AddBG(MakeRect(0, 0, 1000, 500), eUIState_Normal).SetAlpha(0.75f);
		break;
	}
	// Set  up the navigation *after* the alert is built, so that the button visibility can be used. 
	RefreshNavigation();
	// if (!Movie.IsMouseActive())
	// {
	// 	Navigator.Clear();
	// }
}

simulated function Name GetLibraryID()
{
	//This gets the Flash library name to load in a panel. No name means no library asset yet. 
	switch ( eAlertName )
	{	
	case 'eAlert_TrainingComplete': return 'Alert_TrainingComplete';
	default:
		return '';
	}
}



simulated function BuildConditionTrainingCompleteAlert(string TitleLabel)
{
	local XComGameState_Unit UnitState;
	local X2AbilityTemplate TrainedAbilityTemplate;	
	local X2AbilityTemplateManager AbilityTemplateManager;
	local XGParamTag kTag;
	local XComGameState_ResistanceFaction FactionState;
	local string AbilityIcon, AbilityName, AbilityDescription, ClassIcon, ClassName, RankName, ExtraInfo;	
	
	if( LibraryPanel == none )
	{
		`RedScreen("UI Problem with the alerts! Couldn't find LibraryPanel for current eAlertName: " $ eAlertName);
		return;
	}

	UnitState = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(
		class'X2StrategyGameRulesetDataStructures'.static.GetDynamicIntProperty(DisplayPropertySet, 'UnitRef')));
	// Start Issue #106
	ClassName = Caps(UnitState.GetSoldierClassDisplayName());
	ClassIcon = UnitState.GetSoldierClassIcon();
	// End Issue #106
	RankName = Caps(UnitState.GetSoldierRankName()); // Issue #408
	
	FactionState = UnitState.GetResistanceFaction();

	kTag = XGParamTag(`XEXPANDCONTEXT.FindTag("XGParam"));
	kTag.StrValue0 = "";

	ExtraInfo = class'X2StrategyGameRulesetDataStructures'.static.GetDynamicStringProperty(DisplayPropertySet, 'ExtraInfo');

	AbilityTemplateManager = class'X2AbilityTemplateManager'.static.GetAbilityTemplateManager();
	TrainedAbilityTemplate = AbilityTemplateManager.FindAbilityTemplate(
		class'X2StrategyGameRulesetDataStructures'.static.GetDynamicNameProperty(DisplayPropertySet, 'AbilityTemplate'));    
    
    // AbilityName = TrainedAbilityTemplate.LocFriendlyName != "" ? TrainedAbilityTemplate.LocFriendlyName : ("Missing 'LocFriendlyName' for ability '" $ TrainedAbilityTemplate.DataName $ "'");
    // AbilityDescription = TrainedAbilityTemplate.HasLongDescription() ? TrainedAbilityTemplate.GetMyLongDescription(, UnitState) : ("Missing 'LocLongDescription' for ability " $ TrainedAbilityTemplate.DataName $ "'");
    AbilityIcon = TrainedAbilityTemplate.IconImage;
	//j = class'UIChooseClass_ConditionSoldier'.default.arrStatForConditioning.find('Stat', default.Stat);
	// AbilityIcon = class'UIChooseClass_ConditionSoldier'.default.arrStatForConditioning[j].img; // TO BE REMOVED!
	AbilityDescription = ExtraInfo;	
	AbilityName = class'UIChooseClass_TrainSpecialist'.default.m_strStatTitle;

	// Send over to flash
	LibraryPanel.MC.BeginFunctionOp("UpdateData");
	LibraryPanel.MC.QueueString(TitleLabel);
	LibraryPanel.MC.QueueString("");
	LibraryPanel.MC.QueueString(ClassIcon);
	LibraryPanel.MC.QueueString(RankName);
	LibraryPanel.MC.QueueString(UnitState.GetName(eNameType_FullNick));
	LibraryPanel.MC.QueueString(ClassName);
	LibraryPanel.MC.QueueString(AbilityIcon); // Ability Icon
	LibraryPanel.MC.QueueString(m_strBonusCS); // From localization
	LibraryPanel.MC.QueueString(AbilityName); // Training description as per UIChooseClass_ConditionSoldier
	LibraryPanel.MC.QueueString(AbilityDescription); // Extra Info from XComGameState_HeadquartersProjectConditionSoldier
	LibraryPanel.MC.QueueString(m_strViewSoldier);
	// LibraryPanel.MC.QueueString(m_strCarryOn);
	LibraryPanel.MC.QueueString(m_strContinueCSTraining);
	LibraryPanel.MC.EndOp();
	GetOrStartWaitingForStaffImage();

	//Set icons before hiding the button.
	Button1.SetGamepadIcon(class'UIUtilities_Input'.static.GetGamepadIconPrefix() $ class'UIUtilities_Input'.const.ICON_X_SQUARE);
	Button2.SetGamepadIcon(class'UIUtilities_Input'.static.GetAdvanceButtonIcon());
	
	//bsg-crobinson (5.17.17): Buttons need to be in a different area for this screen
	Button1.OnSizeRealized = OnTrainingButtonRealized;
	Button2.OnSizeRealized = OnTrainingButtonRealized;
	//bsg-crobinson (5.17.17): end

	// Hide "View Soldier" button if player is on top of avenger, prevents ui state stack issues
	if (Movie.Pres.ScreenStack.IsInStack(class'UIArmory_Promotion'))
	{
		Button1.Hide(); 
		Button1.DisableNavigation();
	}

	if (FactionState != none)
		SetFactionIcon(FactionState.GetFactionIcon());
}