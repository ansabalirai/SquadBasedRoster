//---------------------------------------------------------------------------------------
//  FILE:    XComGameStateContext_HeadquartersOrderSBR.uc
//  AUTHOR:  Rai
//  PURPOSE: ?
//---------------------------------------------------------------------------------------

class XComGameStateContext_HeadquartersOrderSBR extends XComGameStateContext_HeadquartersOrder config(SquadBasedRoster);



static function CompleteTrainRookie(XComGameState AddToGameState, StateObjectReference ProjectRef)
{   
	local XComGameState_HeadquartersProjectTrainSpecialist ProjectState;
	local XComGameState_HeadquartersXCom XComHQ;
	local XComGameState_SBRSquadManager SquadMgr;
    local XComGameState_SBRSquad Squad;
	local XComGameState_Unit UnitState, UpdatedUnit;
    local XComGameStateContext_ChangeContainer ChangeContainer;
    local XComGameState UpdateState;
    local XComGameState_Unit_SBRSpecialist SpecialistState;
	local XComGameState_StaffSlot StaffSlotState;
	local XComGameStateHistory History;	
	local array<XComGameState_Item> EquippedImplants;
	local XComGameState_Item CombatSim;
    local int idx, j, Bonus, NewStat, AbilityPointsGranted;
	local X2AbilityTemplate AbilityTemplate;
	local ClassAgnosticAbility Ability;
	local SoldierClassAbilityType AbilityType;
	local array<name> GrantedAbilities;	
	local name GrantedAbility, FactionName;

	History = `XCOMHISTORY;
	ProjectState = XComGameState_HeadquartersProjectTrainSpecialist(`XCOMHISTORY.GetGameStateForObjectID(ProjectRef.ObjectID));

	if (ProjectState != none)
	{
		XComHQ = XComGameState_HeadquartersXCom(History.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersXCom'));
		if (XComHQ != none)
		{
			XComHQ = XComGameState_HeadquartersXCom(AddToGameState.ModifyStateObject(class'XComGameState_HeadquartersXCom', XComHQ.ObjectID));
			XComHQ.Projects.RemoveItem(ProjectState.GetReference());
			AddToGameState.RemoveStateObject(ProjectState.ObjectID);
		}

		UnitState = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(ProjectState.ProjectFocus.ObjectID));
		if (UnitState != none)
		{
			// Set the soldier status back to active
			UnitState = XComGameState_Unit(AddToGameState.ModifyStateObject(class'XComGameState_Unit', UnitState.ObjectID));
            UnitState.SetStatus(eStatus_Active);
            
            // Apply the specialist component to the soldier from the Project State
			// Set faction type correctly: 1=Reapers, 2=Skirmishers, 3=Templars
			FactionName = ProjectState.Faction;
			if (FactionName == 'Faction_Reapers')
	            UnitState.SetUnitFloatValue('SBR_SpecialistTrainingFactionType', 1.0, eCleanup_Never);
			else if (FactionName == 'Faction_Skirmishers')
	            UnitState.SetUnitFloatValue('SBR_SpecialistTrainingFactionType', 2.0, eCleanup_Never);
			else if (FactionName == 'Faction_Templars')
	            UnitState.SetUnitFloatValue('SBR_SpecialistTrainingFactionType', 3.0, eCleanup_Never);

			SquadMgr = class'XComGameState_SBRSquadManager'.static.GetSquadManager();
			for(idx = 0; idx < SquadMgr.Squads.Length; idx++)
			{
				Squad = SquadMgr.GetSquad(idx);
				if(Squad.UnitIsInSquad(UnitState.GetReference()))
				{
					if ( XComGameState_ResistanceFaction(History.GetGameStateForObjectID(Squad.Faction.ObjectID)).GetMyTemplateName() == FactionName )
						Squad.Specialists.AddItem(UnitState.GetReference());
					break;
				}
					
			}

            // May uncomment them if needed. For now we just need to add abilities maybe
/*          // Update stat first
            j = default.arrStatRanges.find('Stat', ProjectState.ConditionStat);
            Bonus = class'X2DownloadableContentInfo_WOTC_SoldierConditioning'.static.RollBonus(UnitState.ComInt, default.arrStatRanges[j]);
			ProjectState.StatBonus = Bonus;
            NewStat = UnitState.GetMaxStat(ProjectState.ConditionStat) + Bonus;
            UnitState.SetBaseMaxStat(ProjectState.ConditionStat, NewStat);    

            `LOG("Which stat:" @ProjectState.ConditionStat, class'X2DownloadableContentInfo_WOTC_SoldierConditioning'.default.bEnableLog, 'WOTC_SolderConditioning');
            `LOG("Bonus:" @Bonus, class'X2DownloadableContentInfo_WOTC_SoldierConditioning'.default.bEnableLog, 'WOTC_SolderConditioning');
            `LOG("NewStat:" @NewStat, class'X2DownloadableContentInfo_WOTC_SoldierConditioning'.default.bEnableLog, 'WOTC_SolderConditioning');

            // Give Ability Points
            `LOG("UnitState.AbilityPoints (before):" @UnitState.AbilityPoints, class'X2DownloadableContentInfo_WOTC_SoldierConditioning'.default.bEnableLog, 'WOTC_SolderConditioning');
			AbilityPointsGranted = class'X2DownloadableContentInfo_WOTC_SoldierConditioning'.static.GiveAbilityPoints(UnitState.ComInt);
            UnitState.AbilityPoints += AbilityPointsGranted;
			ProjectState.AbilityPointsGranted = AbilityPointsGranted;
            `LOG("UnitState.AbilityPoints (after):" @UnitState.AbilityPoints, class'X2DownloadableContentInfo_WOTC_SoldierConditioning'.default.bEnableLog, 'WOTC_SolderConditioning');  */

            // Grant abilities
            class'X2Helper_SquadBasedRoster'.static.GetAbilities(UnitState.ComInt, GrantedAbilities, UnitState, FactionName);			
			ProjectState.GrantedAbilities = GrantedAbilities;

            foreach GrantedAbilities(GrantedAbility){
                AbilityTemplate = class'X2AbilityTemplateManager'.static.GetAbilityTemplateManager().FindAbilityTemplate(GrantedAbility);
                
				if(AbilityTemplate != none)
				{
					AbilityType.AbilityName = AbilityTemplate.DataName;
					`LOG("SBR: Ability:" @AbilityTemplate.DataName @ "added to"@ UnitState.GetFullName()); 

					Ability.AbilityType = AbilityType;
					Ability.bUnlocked = true;
					Ability.iRank = 0;
					UnitState.bSeenAWCAbilityPopup = true;
					UnitState.AWCAbilities.AddItem(Ability);

					ProjectState.AbilityTemplate = AbilityTemplate;
				}
				else
				{
					`LOG("SBR: Invalid Ability:" @AbilityTemplate.DataName @ "NOT added to"@ UnitState.GetFullName()); 
				}
            }        

/* 			// Will reduction
            class'X2DownloadableContentInfo_WOTC_SoldierConditioning'.static.GetReducedWill(UnitState, AddToGameState);  */   

            // Set unit value so each soldier can only do this training one time
            UnitState.SetUnitFloatValue('SBR_SpecialistTraining', 1.0, eCleanup_Never);


			// Remove the soldier from the staff slot
			StaffSlotState = UnitState.GetStaffSlot();
			if (StaffSlotState != none)
			{
				StaffSlotState.EmptySlot(AddToGameState);
			}

            UpdateState.AddStateObject(UpdatedUnit);
			UpdateState.AddStateObject(SpecialistState);
			`GAMERULES.SubmitGameState(UpdateState);
		}
	}
}


static function IssueHeadquartersOrderSBR(const out HeadquartersOrderInputContext UseInputContext)
{
	local XComGameStateContext_HeadquartersOrder NewOrderContext;

	NewOrderContext = XComGameStateContext_HeadquartersOrder(class'XComGameStateContext_HeadquartersOrderSBR'.static.CreateXComGameStateContext());
	NewOrderContext.InputContext = UseInputContext;

	`GAMERULES.SubmitGameStateContext(NewOrderContext);
}