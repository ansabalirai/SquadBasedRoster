//---------------------------------------------------------------------------------------
//  FILE:    UIChooseClass_TrainSpecialist.uc
//  AUTHOR:  Rai
//  PURPOSE: ?
//---------------------------------------------------------------------------------------

class UIChooseClass_TrainSpecialist extends UIChooseClass config(SquadBasedRoster);

struct ClassesForTraining
{
    var name ClassName;
	var string ClassImagePath;
};

var config array<ClassesForTraining> arrClassesForTraining; // Expect the three hero factions here
var localized string m_strStatTitle;
var localized string m_strStatDesc;

//--------------------------------------------------------------------------------------
simulated function array<Commodity> ConvertClassesToCommodities()
{
	// local X2SoldierClassTemplate ClassTemplate;
	// local int iClass;
	local array<Commodity> arrCommodoties;
    local Commodity ClassComm;
    local ClassesForTraining Faction;
    local XGParamTag LocTag;
    local XComGameState_Unit UnitState;
    local XComGameState_HeadquartersResistance ResHQ;
	local XComGameState_ResistanceFaction FactionState;
	local array<XComGameState_ResistanceFaction> AllFactions;
    local int j;
    
    UnitState = XComGameState_Unit(History.GetGameStateForObjectID(m_UnitRef.ObjectID));
    ResHQ = XComGameState_HeadquartersResistance(History.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersResistance'));
	
	AllFactions = ResHQ.GetAllFactions();

    LocTag = XGParamTag(`XEXPANDCONTEXT.FindTag("XGParam"));
	
    foreach default.arrClassesForTraining(Faction)
    {


        ClassComm.Title = m_strStatTitle;
        ClassComm.Image = Faction.ClassImagePath;
        ClassComm.Desc = `XEXPAND.ExpandString(m_strStatDesc);
        ClassComm.OrderHours = class'X2Helper_SquadBasedRoster'.static.GetTrainingDays(UnitState) * 24;
     
        foreach AllFactions(FactionState)
        {
            // Only allow training for a specilization if we have met the corresponding faction
            if (FactionState.GetMyTemplateName() == Faction.ClassName && FactionState.bMetXCom)
            {
                arrCommodoties.AddItem(ClassComm);
            }
        }
        
    } 
	return arrCommodoties;
}

function bool OnClassSelected(int iOption)
{
	local XComGameState NewGameState;
	local XComGameState_FacilityXCom FacilityState;
	local XComGameState_StaffSlot StaffSlotState;	
	local XComGameState_HeadquartersProjectTrainSpecialist ProjectState;
	local StaffUnitInfo UnitInfo;		
	
	FacilityState = XComHQ.GetFacilityByName('OfficerTrainingSchool');	
	StaffSlotState = FacilityState.GetEmptyStaffSlotByTemplate('SBR_SpecialistTrainingSlot');
	
	if (StaffSlotState != none)
	{
		// The Training project is started when the staff slot is filled. Pass in the NewGameState so the project can be found below.
		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Staffing Specialist Training Slot");
		UnitInfo.UnitRef = m_UnitRef;
		StaffSlotState.FillSlot(UnitInfo, NewGameState);
		
		// Find the new Training Project which was just created by filling the staff slot and set the class		
		foreach NewGameState.IterateByClassType(class'XComGameState_HeadquartersProjectTrainSpecialist', ProjectState)
		{			
			// ProjectState.NewClassName = m_arrClasses[iOption].DataName;
            ProjectState.Faction = default.arrClassesForTraining[iOption].ClassName;
			ProjectState.FactionIconPath = default.arrClassesForTraining[iOption].ClassImagePath;
			break;
		}
		
		`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);
		`XSTRATEGYSOUNDMGR.PlaySoundEvent("StrategyUI_Staff_Assign");		
		RefreshFacility();
	}
    return true;
}

defaultproperties
{
	InputState = eInputState_Consume;

	bHideOnLoseFocus = true;	

	DisplayTag="UIDisplay_Academy"
	CameraTag="UIDisplay_Academy"
}