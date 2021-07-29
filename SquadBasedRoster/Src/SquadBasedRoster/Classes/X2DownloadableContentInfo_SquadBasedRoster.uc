class X2DownloadableContentInfo_SquadBasedRoster extends X2DownloadableContentInfo config(SquadBasedRoster);

var config bool GO_CLASSLESS;
// The class for all default non-faction soldiers
var config name STARTING_CLASS_NAME;
var config array<name> arrAbilityList; //For adding random abilities based on EL



static event OnLoadedSavedGame()
{
    class'X2Helper_SquadBasedRoster'.static.AddSlotToExistingFacility('SBR_SpecialistTrainingSlot', 'OfficerTrainingSchool');
    OnLoadedSavedGameToStrategy();
}


static event InstallNewCampaign(XComGameState StartState)
{
	local XComGameState_Unit StartingFactionSoldier2;
    local XComGameState_HeadquartersXCom XComHQ;

    `Log("SquadBasedRoster: Installing a new campaign");
	class'XComGameState_SBRSquadManager'.static.CreateSquadManager(StartState);
    class'XComGameState_SBRSquadManager'.static.CreateFirstMissionSquad(StartState);

    
    foreach StartState.IterateByClassType(class'XComGameState_HeadquartersXCom', XComHQ)
	{
		break;
	}
	if (XComHQ == none)
	{
		XComHQ = `XCOMHQ;
		XComHQ = XComGameState_HeadquartersXCom(StartState.ModifyStateObject(class'XComGameState_HeadquartersXCom', XComHQ.ObjectID));
	}

    // Give an extra faction soldier of the contacted faction
    `Log("SquadBasedRoster: Adding a 2nd faction solider to barracks");
    StartingFactionSoldier2 = XComHQ.CreateStartingFactionSoldier(StartState);
	if (StartingFactionSoldier2 != none)
    {
        XComHQ.AddToCrew(StartState, StartingFactionSoldier2);
    }
}




static event OnPostTemplatesCreated()
{
	//UpdateDefaultSoldiers();
    class'X2Helper_SquadBasedRoster'.static.AddSlotToFacility('OfficerTrainingSchool', 'SBR_SpecialistTrainingSlot', false);	
}

static event OnLoadedSavedGameToStrategy()
{
    local XComGameState NewGameState;
    local XComGameState_SBRSquadManager SquadMgrState;
    local bool bSquadManagerExist;

	bSquadManagerExist = FALSE;

    foreach `XCOMHISTORY.IterateByClassType(class'XComGameState_SBRSquadManager', SquadMgrState)
    {
        bSquadManagerExist = true;
    }

    if (!bSquadManagerExist)
    {
        // Create new Game State
		`Log("SquadBasedRoster: Loading mod in an ongoing campaign");
        NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("SquadManager: Mid campaign install");
        SquadMgrState = XComGameState_SBRSquadManager(NewGameState.CreateNewStateObject(class'XComGameState_SBRSquadManager'));
        SquadMgrState.InitSquadManagerListeners();
        NewGameState.AddStateObject(SquadMgrState);
        `GAMERULES.SubmitGameState(NewGameState);
    }
}


static event OnPreMission(XComGameState StartGameState, XComGameState_MissionSite MissionState)
{
	local XComGameState_SBRSquadManager SqdMgr;
    local X2SitRepTemplateManager SitRepMgr;
    local XComGameState_SBRSquad SquadState;
    local array<SoldierRankAbilities> StartingAbilities;
    local X2SitRepTemplate SitRepTemplate;
	local int idx, jdx;

    SqdMgr = class'XComGameState_SBRSquadManager'.static.GetSquadManager();
    SitRepMgr = class'X2SitRepTemplateManager'.static.GetSitRepTemplateManager();

    // If we want a squad wide specific buff or something that does not need to depend on each unit's weapon ref for example, we can use this hook
    //class'X2Helper_SquadBasedRoster'.static.ApplySBRSitreps(MissionState);

    // We need to set the OnMissionStatus and MissionRef for the squad loading into the mission to ensure that postmission
    // handling happens correctly
    class'XComGameState_SBRSquadManager'.static.GetSquadManager().UpdateSquadPreMission();

}



static event OnPostMission()
{
	//class'XComGameState_LWListenerManager'.static.RefreshListeners();

	class'XComGameState_SBRSquadManager'.static.GetSquadManager().UpdateSquadPostMission(, true); // completed mission
	//`LWOUTPOSTMGR.UpdateOutpostsPostMission();

}










// In case we want to run with out own soldier class
static function UpdateDefaultSoldiers()
{
	local X2CharacterTemplateManager CharacterTemplateManager;
	local X2CharacterTemplate SoldierTemplate;

	CharacterTemplateManager = class'X2CharacterTemplateManager'.static.GetCharacterTemplateManager();
	SoldierTemplate = CharacterTemplateManager.FindCharacterTemplate('Soldier');
	SoldierTemplate.DefaultSoldierClass = default.STARTING_CLASS_NAME;
}


static function FinalizeUnitAbilitiesForInit(XComGameState_Unit UnitState, out array<AbilitySetupData> SetupData, optional XComGameState StartState, optional XComGameState_Player PlayerState, optional bool bMultiplayerDisplay)
{
	local X2AbilityTemplate AbilityTemplate;
    local XComGameState_HeadquartersXCom XCOMHQ;
	local X2AbilityTemplateManager AbilityTemplateMan;
    local XComGameState_SBRSquadManager SqdMgr;
    local XComGameState_SBRSquad Squad;
    local XComGameState_Unit FactionLeader;
	local name AbilityName, FactionName, SpecialistFactionName;
	local AbilitySetupData Data, EmptyData;
	local X2CharacterTemplate CharTemplate;
    local StateObjectReference MissionRef, UnitRef, FactionRef;
    local array<name> PrimaryWeaponAbilitiesToAdd, SecondaryWeaponAbilitiesToAdd, PrimaryWeaponAbilitiesToRemove, SecondaryWeaponAbilitiesToRemove;
	local int i, j, SpecsAllowed, SpecsOnMission, currSoldierIdx;
    local float EL;
    local array<int> SpecData;
    local bool bRemoveAbilities;


    XCOMHQ = `XCOMHQ;
    CharTemplate = UnitState.GetMyTemplate();
	if (CharTemplate == none)
		return;   

    AbilityTemplateMan = class'X2AbilityTemplateManager'.static.GetAbilityTemplateManager();
    SqdMgr = class'XComGameState_SBRSquadManager'.static.GetSquadManager();
    MissionRef = XComHQ.MissionRef;
    Squad = SqdMgr.GetSquadOnMission(MissionRef);

    // Fill the PrimaryWeaponAbilities and SecondaryWeaponAbilities
    PrimaryWeaponAbilitiesToAdd.AddItem('Camaraderie'); // Adds EL related stat buffs

    for (i = 0; i < class'X2Helper_SquadBasedRoster'.default.arrAbilityListTemplars.Length; i++)
    {
        PrimaryWeaponAbilitiesToRemove.AddItem(class'X2Helper_SquadBasedRoster'.default.arrAbilityListTemplars[i]);
    }
    for (i = 0; i < class'X2Helper_SquadBasedRoster'.default.arrAbilityListReapers.Length; i++)
    {
        PrimaryWeaponAbilitiesToRemove.AddItem(class'X2Helper_SquadBasedRoster'.default.arrAbilityListReapers[i]);
    }
    for (i = 0; i < class'X2Helper_SquadBasedRoster'.default.arrAbilityListSkirmishers.Length; i++)
    {
        PrimaryWeaponAbilitiesToRemove.AddItem(class'X2Helper_SquadBasedRoster'.default.arrAbilityListSkirmishers[i]);
    }
    
    // Check how many specialists are allowed per mission (based on squad size unlocks and figure out if we need some culling)
    SpecData = class'X2Helper_SquadBasedRoster'.static.GetSpecialistsToBeCulled(XCOMHQ.Squad, Squad);


    // Check using issoldier for now and making sure that we only apply buffs to soldiers in the deployed squad
    if (UnitState.IsSoldier() && (XCOMHQ.Squad.Find('ObjectID', UnitState.GetReference().ObjectID) != -1))
    {

        currSoldierIdx = XCOMHQ.Squad.Find('ObjectID', UnitState.GetReference().ObjectID);
        if (SpecData[currSoldierIdx] == 1)
            bRemoveAbilities = true;
        else
            bRemoveAbilities = false;




/*         //Remove abilities before adding, e.g. for specialists in a non-affiliated squad?
        if (class'X2Helper_SquadBasedRoster'.static.IsUnitASpecialist(UnitState,SpecialistFactionName))
        {
            bRemoveAbilities = true;
            foreach XCOMHQ.Squad(UnitRef)
            {
                FactionLeader = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(UnitRef.ObjectID));
                if (FactionLeader.GetResistanceFaction().GetMyTemplateName() == SpecialistFactionName)
                {
                    bRemoveAbilities = false;
                    break;
                }
            } */
        // We may need some handling here in case we are running classless and need to remove more class based abilities for the specialists in case they are deployed without a leader
        if (bRemoveAbilities)
        {
            for (i = 0; i < PrimaryWeaponAbilitiesToRemove.Length; ++i)
            {
                AbilityName = PrimaryWeaponAbilitiesToRemove[i];
                AbilityTemplate = AbilityTemplateMan.FindAbilityTemplate(AbilityName);
                if (AbilityTemplate != none && !AbilityTemplate.bUniqueSource)
                {

                    for (j = SetupData.Length - 1; j >= 0; --j)
                    {
                        if (SetupData[j].TemplateName == AbilityName)
                        {
                            SetupData.Remove(j,1); // Hope there are no multiples ??
                            break;
                        }
                    }
                }
            }

        }


        // Adding EL specific abilities regardless of squad composition
        UnitRef = UnitState.GetReference();
        EL = Squad.GetEffectiveLevelOnMission(UnitRef, XCOMHQ.Squad, FactionRef);
        if (FactionRef.ObjectID != 0)
        {
            FactionName = Squad.GetSquadFaction();
        }
        //add the abilities based on EL
        class'X2Helper_SquadBasedRoster'.static.GetAbilitiesForEL(EL, PrimaryWeaponAbilitiesToAdd, UnitState, FactionName);
        for (i = 0; i < PrimaryWeaponAbilitiesToAdd.Length; ++i)
        {
            AbilityName = PrimaryWeaponAbilitiesToAdd[i];
            AbilityTemplate = AbilityTemplateMan.FindAbilityTemplate(AbilityName);
            if (AbilityTemplate != none && !AbilityTemplate.bUniqueSource)
            {
                Data = EmptyData;
                Data.TemplateName = AbilityName;
                Data.Template = AbilityTemplate;
                Data.SourceWeaponRef = UnitState.GetPrimaryWeapon().GetReference();
                SetupData.AddItem(Data);  // return array
            }
        }

    }
}

/// Calls DLC specific popup handlers to route messages to correct display functions
/// </summary>
static function bool DisplayQueuedDynamicPopup(DynamicPropertySet PropertySet)
{
	if (PropertySet.PrimaryRoutingKey == 'UIAlert_TrainSpecialist')
	{
		CallUIAlert_TrainSpecialist(PropertySet);
		return true;
	}

	return false;
}

static function CallUIAlert_TrainSpecialist(const out DynamicPropertySet PropertySet)
{
	local XComHQPresentationLayer Pres;
	local UIAlert_TrainSpecialist Alert;

	Pres = `HQPRES;

	Alert = Pres.Spawn(class'UIAlert_TrainSpecialist', Pres);
	Alert.DisplayPropertySet = PropertySet;
	Alert.eAlertName = PropertySet.SecondaryRoutingKey;

	Pres.ScreenStack.Push(Alert);
}


// Print the status and location for all soldiers in all squads
exec function PrintSquadSoldierStatus()
{
    local XComGameState_SBRSquadManager SqdMgr;
    local XComGameState_SBRSquad SquadState;
	local int idx;

    SqdMgr = class'XComGameState_SBRSquadManager'.static.GetSquadManager();

	for(idx = 0; idx < SqdMgr.Squads.Length; idx++)
	{
		SquadState = SqdMgr.GetSquad(idx);
        SquadState.GetSquadSoldierStatus();
		
	}  
}


// Helper to add abilities based on EL specified in config
static function AddELSpecificAbilities( array<name> AbilitiesToAdd, optional float EL)
{

}