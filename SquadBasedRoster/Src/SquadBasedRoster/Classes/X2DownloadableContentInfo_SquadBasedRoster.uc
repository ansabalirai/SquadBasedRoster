class X2DownloadableContentInfo_SquadBasedRoster extends X2DownloadableContentInfo config(SquadBasedRoster);

// The class for all default non-faction soldiers
var config name STARTING_CLASS_NAME;

static event OnLoadedSavedGame()
{
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
	local name AbilityName;
	local AbilitySetupData Data, EmptyData;
	local X2CharacterTemplate CharTemplate;
    local array<name> PrimaryWeaponAbilitiesToAdd, SecondaryWeaponAbilitiesToAdd, PrimaryWeaponAbilitiesToRemove, SecondaryWeaponAbilitiesToRemove;
	local int i;


    XCOMHQ = `XCOMHQ;
    CharTemplate = UnitState.GetMyTemplate();
	if (CharTemplate == none)
		return;   

    AbilityTemplateMan = class'X2AbilityTemplateManager'.static.GetAbilityTemplateManager();

    // Fill the PrimaryWeaponAbilities and SecondaryWeaponAbilities (for now, just hardcode to check)
    //PrimaryWeaponAbilitiesToAdd.AddItem('RapidFire');
    //PrimaryWeaponAbilitiesToAdd.AddItem('RapidFire2');
    PrimaryWeaponAbilitiesToAdd.AddItem('Camaraderie'); // Adds EL related stat buffs

    

    // Check using issoldier for now and making sure that we only apply buffs to soldiers in the deployed squad
    if (UnitState.IsSoldier() && (XCOMHQ.Squad.Find('ObjectID', UnitState.GetReference().ObjectID) != -1))
    {
        //Remove abilities before adding, e.g. for specialists in a non-affiliated squad?
        //To do

        //add the abilities
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