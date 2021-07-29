//---------------------------------------------------------------------------------------
//  FILE:    UISquadSelect_SquadInfoPanel
//  AUTHOR:  Rai / (Adapted from Amineri / Pavonis Interactive)
//
//  PURPOSE: Panel/container for displaying squad level and affinity related information
//--------------------------------------------------------------------------------------- 
class UISquadSelect_SquadInfoPanel extends UIPanel config(SquadBasedRoster);

// Self note: This needs to be called in UIScreenListerner_SquadSelect_LW to actually show the panel

var GeneratedMissionData MissionData;

var vector2d InitPos;

var UIMask InfiltrationMask;

var UIText SquadInfoTitle;
var UIText CurrSquadLevel;
var UIText CurrSquadAffinity;
var UIText CurrSquadEL;

var array<StateObjectReference> SquadSoldiers;

var string SquadInfoTitleText;
var string SquadLevelText;
var string SquadAffinityText;
var string SquadELText;



// do a timer-delayed initiation in order to allow other UI elements to settle
function DelayedInit(float Delay)
{
	SetTimer(Delay, false, nameof(StartDelayedInit));
}

function StartDelayedInit()
{
	InitInfoPanel();
	MCName = 'SquadSelect_SquadInfo';
	Update(SquadSoldiers, SquadLevelText, SquadAffinityText, SquadELText);
}

simulated function UISquadSelect_SquadInfoPanel InitInfoPanel(optional name InitName,
										  optional name InitLibID = '',
										  optional int InitX = -450,
										  optional int InitY = 0,
										  optional int InitWidth = 250,
										  optional int InitHeight = 200)
{
	//local XComGameStateHistory History;
	//local XComGameState_ObjectivesList ObjectiveList;
	//local XComGameState_MissionSite MissionState;

	InitPanel(InitName, InitLibID);
	
	Hide();

	AnchorTopCenter();
	//OriginTopRight();

	SetSize(InitWidth, InitHeight);
	SetPosition(InitX, InitY);

	//Save out this info 
	InitPos = vect2d(X, Y);

	//Debug square to show location:
	//Spawn(class'UIPanel', self).InitPanel('BGBoxSimpleHit', class'UIUtilities_Controls'.const.MC_X2BackgroundShading).SetSize(InitWidth, InitHeight);


	// Setting the text strings
	//SquadLevelText = 
    // this is the squad Info Title
    SquadInfoTitle = Spawn(class'UIText', self);
    SquadInfoTitle.bAnimateOnInit = false;
    SquadInfoTitle.InitText(, GetTextHTMLCaps("Squad Info:",26,"a7a085"));
    SquadInfoTitle.SetPosition(0,0);


    // this is the squad name
    CurrSquadLevel = Spawn(class'UIText', self);
    CurrSquadLevel.bAnimateOnInit = false;
    CurrSquadLevel.InitText(, GetTextHTML("Current Squad Level: ",22,"a7a085"));
    CurrSquadLevel.SetPosition(0,30);

	// This is the squad affinity
    CurrSquadAffinity = Spawn(class'UIText', self);
    CurrSquadAffinity.bAnimateOnInit = false;
    CurrSquadAffinity.InitText(, GetTextHTML("Current Squad Affinity: ",22,"a7a085"));
    CurrSquadAffinity.SetPosition(0,60);	

	// This is the squad average EL
    CurrSquadEL = Spawn(class'UIText', self);
    CurrSquadEL.bAnimateOnInit = false;
    CurrSquadEL.InitText(, GetTextHTML("Current Average EL: ",22,"a7a085"));
    CurrSquadEL.SetPosition(0,90);


	return self;
}


simulated function Update(array<StateObjectReference> Soldiers, string SquadLevelText, string SquadAffinityText, string SquadELText )
{
	local XComGameState_MissionSite MissionState;
	local int SquadSizeHours, CovertnessHours, NumSoldiers, LiberationHours;
	local string Temp;
	local StateObjectReference Soldier;
	
	MissionState = XComGameState_MissionSite(`XCOMHISTORY.GetGameStateForObjectID(MissionData.MissionID));


	foreach Soldiers (Soldier)
	{
		if (Soldier.ObjectID > 0)
			NumSoldiers++;
	}


	Temp = SquadLevelText $ "/" $ string(class'XComGameState_SBRSquadManager'.default.MAX_SQUAD_LEVEL);
	SquadLevelText = GetTextHTML("Current Squad Level: ",22,"a7a085")  $  GetTextHTML(Temp, 22, "53b45e");
	CurrSquadLevel.SetText(SquadLevelText);

	Temp = SquadAffinityText;
	SquadAffinityText = GetTextHTML("Current Squad Affinity: ",22,"a7a085")  $  GetTextHTML(Temp, 22, "53b45e");
	CurrSquadAffinity.SetText(SquadAffinityText);


	Temp = SquadELText $ "/" $ string(class'XComGameState_SBRSquadManager'.default.MAX_SOLDIER_EFFECTIVE_LEVEL);
	SquadELText = GetTextHTML("Current Average EL: ",22,"a7a085")  $  GetTextHTML(Temp, 22, "53b45e");
	CurrSquadEL.SetText(SquadELText);

	if (NumSoldiers == 0)
	{
		CurrSquadLevel.Hide();
		CurrSquadAffinity.Hide();
		CurrSquadEL.Hide();
	}

	Show();

}

simulated function string GetSubTitleHTML(string Text)
{
	return "<font face='$TitleFont' size='22' color='#a7a085'>" $ CAPS(Text) $ "</font>";
}

simulated function string GetTextHTML(string Text, int TextSize, string TextColor)
{
	return "<font face='$NormalFont' size='" $ string(TextSize) $ "' color='#" $ TextColor $ "'>" $ Text  $ "</font>";
}

simulated function string GetTextHTMLCaps(string Text, int TextSize, string TextColor)
{
	return "<font face='$NormalFont' size='" $ string(TextSize) $ "' color='#" $ TextColor $ "'>" $ CAPS(Text)  $ "</font>";
}



//Defaults: ------------------------------------------------------------------------------
defaultproperties
{
	bIsNavigable = false; 
	bAnimateOnInit = false;
} 