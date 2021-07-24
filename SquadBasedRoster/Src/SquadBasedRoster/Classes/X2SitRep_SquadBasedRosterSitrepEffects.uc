class X2SitRep_SquadBasedRosterSitrepEffects extends X2SitRepEffect config(GameData);


static function array<X2DataTemplate> CreateTemplates()
{
	local array<X2DataTemplate> Templates;
	
	// granted abilities
	//Templates.AddItem(CreateRapidFireEffect());

	//`Log(">>>>>>>>>>>>>>>>>>>>>> Added SBR Sitrep Effect Templates <<<<<<<<<<<<<<<<<<<<<");
	//`Log(Templates[0].DataName);
	return Templates;
}


/////////////////////////
/// Granted Abilities ///
/////////////////////////



static function X2SitRepEffectTemplate CreateRapidFireEffect()
{
	local X2SitRepEffect_GrantAbilities Template;
	
	`CREATE_X2TEMPLATE(class'X2SitRepEffect_GrantAbilities', Template, 'RapidFireEffect');

	Template.AbilityTemplateNames.AddItem('RapidFire');
	Template.GrantToSoldiers = true;

	return Template;
}