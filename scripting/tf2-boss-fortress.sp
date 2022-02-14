//Pragma
#pragma semicolon 1
#pragma newdecls required

//Defines
#define PLUGIN_VERSION "1.0.1"

#define MAX_BOSS_DATA_SETS 64
#define NO_BOSS -1

//Includes
#include <sourcemod>
#include <sdkhooks>
#include <tf2_stocks>
#include <tf2items>
#include <tf2attributes>

//ConVars

//Globals

enum struct Bosses
{
	char name[64];
	char model[PLATFORM_MAX_PATH];
	char description[128];

	TFClassType class;

	int base_health;
	float health_multi;

	bool hide_weapon;

	StringMap attributes;

	void AddBoss(const char[] name, const char[] model, const char[] description)
	{
		this.Reset();

		strcopy(this.name, 64, name);
		strcopy(this.model, PLATFORM_MAX_PATH, model);
		strcopy(this.description, 128, description);

		if (strlen(this.model) > 0)
			PrecacheModel(this.model);
		
		this.attributes = new StringMap();
	}

	void Reset()
	{
		this.name = '\0';
		this.model = '\0';

		this.class = TFClass_Unknown;

		this.base_health = 0;
		this.health_multi = 0.0;

		this.hide_weapon = false;

		delete this.attributes;
	}

	void AddAttribute(const char[] attrib, float value)
	{
		this.attributes.SetValue(attrib, value);
	}
}

Bosses g_Bosses[MAX_BOSS_DATA_SETS];
int g_TotalBosses;

bool IsBoss(int boss, const char[] name)
{
	if (boss == -1 || strlen(name) == 0)
		return false;
	
	return StrEqual(g_Bosses[boss].name, name, false);
}

enum struct Boss
{
	int client;
	int boss;

	int rage_cooldown;
	bool rage_active;

	void SetBoss(int client, int boss)
	{
		this.client = client;
		this.boss = boss;
		this.ApplyBossChanges();

		this.rage_cooldown = -1;
		this.rage_active = false;

		PrintToChat(this.client, "Boss Set: %s", g_Bosses[this.boss].name);
		ShowBossInfoMenu(this.client, this.boss);
	}

	void SetRandomBoss(int client)
	{
		this.client = client;
		this.boss = GetRandomInt(0, g_TotalBosses - 1);
		this.ApplyBossChanges();

		PrintToChat(this.client, "Boss Randomly Set: %s", g_Bosses[this.boss].name);
		ShowBossInfoMenu(this.client, this.boss);
	}

	void ApplyBossChanges()
	{
		TF2_ChangeClientTeam(this.client, TFTeam_Blue);
		SetEntityHealth(this.client, this.GetBossMaxHealth());

		TF2_SetPlayerClass(this.client, g_Bosses[this.boss].class, true, false);
		TF2_RegeneratePlayer(this.client);
		TF2_RemoveAllWearables(this.client);

		int melee = GetPlayerWeaponSlot(this.client, TFWeaponSlot_Melee);

		if (IsValidEntity(melee))
		{
			SetEntProp(melee, Prop_Send, "m_iWorldModelIndex", -1);
			SetEntProp(melee, Prop_Send, "m_nModelIndexOverrides", -1, _, 0);
		}

		TF2_RemoveWeaponSlot(this.client, TFWeaponSlot_Primary);
		TF2_RemoveWeaponSlot(this.client, TFWeaponSlot_Secondary);
		EquipWeaponSlot(this.client, TFWeaponSlot_Melee);
		TF2_RemoveWeaponSlot(this.client, TFWeaponSlot_Grenade);
		TF2_RemoveWeaponSlot(this.client, TFWeaponSlot_Building);
		TF2_RemoveWeaponSlot(this.client, TFWeaponSlot_PDA);
		TF2_RemoveWeaponSlot(this.client, TFWeaponSlot_Item1);
		TF2_RemoveWeaponSlot(this.client, TFWeaponSlot_Item2);

		SetVariantString(g_Bosses[this.boss].model);
		AcceptEntityInput(this.client, "SetCustomModel");

		SetEntProp(this.client, Prop_Send, "m_bCustomModelRotates", 1);
		SetEntProp(this.client, Prop_Send, "m_bUseClassAnimations", 1);

		SDKHook(this.client, SDKHook_GetMaxHealth, Boss_GetMaxHealth);

		StringMapSnapshot snap = g_Bosses[this.boss].attributes.Snapshot();

		for (int i = 0; i < snap.Length; i++)
		{
			int size = snap.KeyBufferSize(i);

			char[] key = new char[size];
			snap.GetKey(i, key, size);

			float value;
			g_Bosses[this.boss].attributes.GetValue(key, value);

			TF2Attrib_SetByName(this.client, key, value);
		}

		delete snap;

		TF2Attrib_ApplyMoveSpeedBonus(this.client, 1.5);
	}

	void RemoveBossChanges()
	{
		SetVariantString("");
		AcceptEntityInput(this.client, "SetCustomModel");

		SetEntProp(this.client, Prop_Send, "m_bCustomModelRotates", 0);
		SetEntProp(this.client, Prop_Send, "m_bUseClassAnimations", 0);
		SDKUnhook(this.client, SDKHook_GetMaxHealth, Boss_GetMaxHealth);

		StringMapSnapshot snap = g_Bosses[this.boss].attributes.Snapshot();

		for (int i = 0; i < snap.Length; i++)
		{
			int size = snap.KeyBufferSize(i);

			char[] key = new char[size];
			snap.GetKey(i, key, size);

			TF2Attrib_RemoveByName(this.client, key);
		}

		TF2Attrib_RemoveMoveSpeedBonus(this.client);
	}

	int GetBossMaxHealth()
	{
		return RoundFloat(g_Bosses[this.boss].base_health * (1.0 + (g_Bosses[this.boss].health_multi * GetClientAliveCount())));
	}
}

Boss g_Boss[1];

public Action Boss_GetMaxHealth(int client, int& maxhealth)
{
	int boss = GetClientBoss(client);

	if (boss != NO_BOSS)
	{
		maxhealth = g_Boss[0].GetBossMaxHealth();
		return Plugin_Changed;
	}

	return Plugin_Continue;
}

int GetClientBoss(int client)
{
	for (int i = 0; i < 1; i++)
		if (g_Boss[i].client == client)
			return g_Boss[i].boss;
	
	return NO_BOSS;
}

public Plugin myinfo = 
{
	name = "[TF2] Boss Fortress", 
	author = "Keith Warren (Drixevel)", 
	description = "A clean VSH-esk gamemode.",
	version = PLUGIN_VERSION, 
	url = "https://github.com/drixevel"
};

public void OnPluginStart()
{
	SetupBossData();
}

public void OnPluginEnd()
{
	for (int i = 0; i < 1; i++)
		if (g_Boss[i].client > 0)
			g_Boss[i].RemoveBossChanges();
}

public void OnMapStart()
{
	PrecacheSound("coach/coach_go_here.wav");
}

void SetupBossData()
{
	g_TotalBosses = 0;

	g_Bosses[g_TotalBosses].AddBoss("Saxton Hale", "models/player/saxtonhale/saxtonhale.mdl", "Grants temporary invincibility for a limited time on rage use.");
	g_Bosses[g_TotalBosses].class = TFClass_Soldier;
	g_Bosses[g_TotalBosses].base_health = 500;
	g_Bosses[g_TotalBosses].health_multi = 0.25;
	g_Bosses[g_TotalBosses].hide_weapon = true;
	g_Bosses[g_TotalBosses].AddAttribute("increased jump height", 4.0);
	g_TotalBosses++;

	g_Bosses[g_TotalBosses].AddBoss("Vagineer", "models/player/saxtonhale/vagineer.mdl", "Spawns a mini level 2 sentry on rage use.");
	g_Bosses[g_TotalBosses].class = TFClass_Engineer;
	g_Bosses[g_TotalBosses].base_health = 500;
	g_Bosses[g_TotalBosses].health_multi = 0.15;
	g_Bosses[g_TotalBosses].hide_weapon = true;
	g_Bosses[g_TotalBosses].AddAttribute("increased jump height", 4.0);
	g_TotalBosses++;

	g_Bosses[g_TotalBosses].AddBoss("Christian Brutal Sniper", "models/player/saxtonhale/cbs_v4.mdl", "Abilities are not done yet for this boss.");
	g_Bosses[g_TotalBosses].class = TFClass_Sniper;
	g_Bosses[g_TotalBosses].base_health = 500;
	g_Bosses[g_TotalBosses].health_multi = 0.10;
	g_Bosses[g_TotalBosses].hide_weapon = false;
	g_Bosses[g_TotalBosses].AddAttribute("increased jump height", 4.0);
	g_TotalBosses++;
	
	g_Bosses[g_TotalBosses].AddBoss("Easter Demo", "models/player/saxtonhale/easter_demo.mdl", "Abilities are not done yet for this boss.");
	g_Bosses[g_TotalBosses].class = TFClass_DemoMan;
	g_Bosses[g_TotalBosses].base_health = 500;
	g_Bosses[g_TotalBosses].health_multi = 0.25;
	g_Bosses[g_TotalBosses].hide_weapon = true;
	g_Bosses[g_TotalBosses].AddAttribute("increased jump height", 4.0);
	g_TotalBosses++;

	g_Bosses[g_TotalBosses].AddBoss("Horseless Headless Horsemann", "models/player/saxtonhale/hhh_jr_mk3.mdl", "Abilities are not done yet for this boss.");
	g_Bosses[g_TotalBosses].class = TFClass_DemoMan;
	g_Bosses[g_TotalBosses].base_health = 500;
	g_Bosses[g_TotalBosses].health_multi = 0.25;
	g_Bosses[g_TotalBosses].hide_weapon = true;
	g_Bosses[g_TotalBosses].AddAttribute("increased jump height", 4.0);
	g_TotalBosses++;
	
	g_Bosses[g_TotalBosses].AddBoss("Billy", "models/player/freakfortress2/billy.mdl", "Abilities are not done yet for this boss.");
	g_Bosses[g_TotalBosses].class = TFClass_DemoMan;
	g_Bosses[g_TotalBosses].base_health = 500;
	g_Bosses[g_TotalBosses].health_multi = 0.25;
	g_Bosses[g_TotalBosses].hide_weapon = true;
	g_Bosses[g_TotalBosses].AddAttribute("increased jump height", 4.0);
	g_TotalBosses++;

	g_Bosses[g_TotalBosses].AddBoss("DemoPan", "models/player/freakfortress2/demopan_v1.mdl", "Abilities are not done yet for this boss.");
	g_Bosses[g_TotalBosses].class = TFClass_DemoMan;
	g_Bosses[g_TotalBosses].base_health = 500;
	g_Bosses[g_TotalBosses].health_multi = 0.25;
	g_Bosses[g_TotalBosses].hide_weapon = true;
	g_Bosses[g_TotalBosses].AddAttribute("increased jump height", 4.0);
	g_TotalBosses++;

	g_Bosses[g_TotalBosses].AddBoss("NinjaSpy", "models/player/freakfortress2/ninjaspy_v2_2.mdl", "Abilities are not done yet for this boss.");
	g_Bosses[g_TotalBosses].class = TFClass_Spy;
	g_Bosses[g_TotalBosses].base_health = 500;
	g_Bosses[g_TotalBosses].health_multi = 0.25;
	g_Bosses[g_TotalBosses].hide_weapon = true;
	g_Bosses[g_TotalBosses].AddAttribute("increased jump height", 4.0);
	g_TotalBosses++;
	
	g_Bosses[g_TotalBosses].AddBoss("GentleSpy", "models/player/freakfortress2/the_gentlespy_v1.mdl", "Abilities are not done yet for this boss.");
	g_Bosses[g_TotalBosses].class = TFClass_Spy;
	g_Bosses[g_TotalBosses].base_health = 500;
	g_Bosses[g_TotalBosses].health_multi = 0.25;
	g_Bosses[g_TotalBosses].hide_weapon = true;
	g_Bosses[g_TotalBosses].AddAttribute("increased jump height", 4.0);
	g_TotalBosses++;
}

public void TF2_OnRoundStart(bool full_reset)
{
	PrintToChatAll("Finding new boss...");
	CreateTimer(2.0, Timer_DelayRoundStart, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_DelayRoundStart(Handle timer)
{
	if (GetClientAliveCount() < 1)
		return;
	
	int client = GetRandomClient(true, false, true, 0);
	g_Boss[0].SetRandomBoss(client);

	PrintToChatAll("Boss Found in %N.", client);

	for (int i = 1; i <= MaxClients; i++)
		if (IsClientInGame(i) && TF2_GetClientTeam(client) > TFTeam_Spectator && GetClientBoss(i) == NO_BOSS)
			TF2_ChangeClientTeam(i, TFTeam_Red);
}

public void TF2_OnRoundEnd(int team, int winreason, int flagcaplimit, bool full_round, float round_time, int losing_team_num_caps, bool was_sudden_death)
{
	for (int i = 0; i < 1; i++)
		if (g_Boss[i].client > 0)
			g_Boss[i].RemoveBossChanges();
}

int GetRandomClient(bool ingame = true, bool alive = false, bool fake = false, int team = 0)
{
	int[] clients = new int[MaxClients];
	int amount;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (ingame && !IsClientInGame(i) || alive && !IsPlayerAlive(i) || !fake && IsFakeClient(i) || team > 0 && team != GetClientTeam(i))
			continue;

		clients[amount++] = i;
	}

	return (amount == 0) ? -1 : clients[GetRandomInt(0, amount - 1)];
}

int GetClientAliveCount()
{
	int count;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || IsClientSourceTV(i) || !IsPlayerAlive(i))
			continue;

		count++;
	}

	return count;
}

void TF2_RemoveAllWearables(int client)
{
	int entity;
	while ((entity = FindEntityByClassname(entity, "tf_wearable*")) != -1)
		if (GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity") == client)
			TF2_RemoveWearable(client, entity);
}

void EquipWeaponSlot(int client, int slot)
{
	int iWeapon = GetPlayerWeaponSlot(client, slot);
	
	if (IsValidEntity(iWeapon))
	{
		char class[64];
		GetEntityClassname(iWeapon, class, sizeof(class));
		FakeClientCommand(client, "use %s", class);
	}
}

public Action TF2_OnPlayerDamaged(int victim, TFClassType victimclass, int& attacker, TFClassType attackerclass, int& inflictor, float& damage, int& damagetype, int& weapon, float damageForce[3], float damagePosition[3], int damagecustom, bool alive)
{
	int boss = GetClientBoss(victim);

	if (boss != NO_BOSS && (damagetype & DMG_FALL) == DMG_FALL)
	{
		damage = 0.0;
		return Plugin_Changed;
	}

	if (IsBoss(boss, "Saxton Hale") && g_Boss[boss].rage_active)
	{
		damage = 0.0;
		return Plugin_Changed;
	}
	
	return Plugin_Continue;
}

void TF2Attrib_ApplyMoveSpeedBonus(int client, float value)
{
	TF2Attrib_SetByName(client, "move speed bonus", 1.0 + value);
	TF2_AddCondition(client, TFCond_SpeedBuffAlly, 0.0);
}

void TF2Attrib_RemoveMoveSpeedBonus(int client)
{
	TF2Attrib_RemoveByName(client, "move speed bonus");
	TF2_AddCondition(client, TFCond_SpeedBuffAlly, 0.0);
}

public Action TF2_OnCallMedic(int client)
{
	int boss = GetClientBoss(client);

	if (boss != NO_BOSS)
	{
		int time = GetTime();
		if (g_Boss[0].rage_cooldown != -1 && g_Boss[0].rage_cooldown > time)
			return Plugin_Stop;
		
		g_Boss[0].rage_cooldown = time + 30;
		
		if (IsBoss(boss, "Saxton Hale"))
		{
			if (g_Boss[0].rage_active)
				return Plugin_Stop;
			
			g_Boss[0].rage_active = true;
			CreateTimer(10.0, Timer_DisableRage, client, TIMER_FLAG_NO_MAPCHANGE);

			SetEntityRenderColor(client, 255, 150, 150, 255);

			EmitSoundToAll("coach/coach_go_here.wav", client);
		}
		else if (IsBoss(boss, "Vagineer"))
		{
			float origin[3];
			GetClientAbsOrigin(client, origin);

			float angles[3];
			GetClientAbsAngles(client, angles);

			VectorAddRotatedOffset(angles, origin, view_as<float>({50.0, 0.0, 0.0}));

			TF2_SpawnSentry(client, origin, angles, TF2_GetClientTeam(client), 1, false, true);
			EmitSoundToAll("coach/coach_go_here.wav", client);
		}

		return Plugin_Stop;
	}

	return Plugin_Continue;
}

public Action Timer_DisableRage(Handle timer, any data)
{
	int client = data;
	int boss = GetClientBoss(client);

	g_Boss[boss].rage_active = false;
	SetEntityRenderColor(client, 255, 255, 255, 255);
}

int TF2_SpawnSentry(int builder, float Position[3], float Angle[3], TFTeam team = TFTeam_Unassigned, int level = 0, bool mini = false, bool disposable = false)
{
	static const float m_vecMinsMini[3] = {-15.0, -15.0, 0.0}, m_vecMaxsMini[3] = {15.0, 15.0, 49.5};
	static const float m_vecMinsDisp[3] = {-13.0, -13.0, 0.0}, m_vecMaxsDisp[3] = {13.0, 13.0, 42.9};
	
	int sentry = CreateEntityByName("obj_sentrygun");
	
	if (IsValidEntity(sentry))
	{
		char sLevel[12];
		IntToString(level, sLevel, sizeof(sLevel));
		
		if (builder > 0)
			AcceptEntityInput(sentry, "SetBuilder", builder);

		SetVariantInt(view_as<int>(team));
		AcceptEntityInput(sentry, "SetTeam");
		
		DispatchKeyValueVector(sentry, "origin", Position);
		DispatchKeyValueVector(sentry, "angles", Angle);
		DispatchKeyValue(sentry, "defaultupgrade", sLevel);
		DispatchKeyValue(sentry, "spawnflags", "4");
		SetEntProp(sentry, Prop_Send, "m_bBuilding", 1);
		
		if (mini || disposable)
		{
			SetEntProp(sentry, Prop_Send, "m_bMiniBuilding", 1);
			SetEntProp(sentry, Prop_Send, "m_nSkin", level == 0 ? view_as<int>(team) : view_as<int>(team) - 2);
		}
		
		if (mini)
		{
			DispatchSpawn(sentry);
			
			SetVariantInt(100);
			AcceptEntityInput(sentry, "SetHealth");
			
			SetEntPropFloat(sentry, Prop_Send, "m_flModelScale", 0.75);
			SetEntPropVector(sentry, Prop_Send, "m_vecMins", m_vecMinsMini);
			SetEntPropVector(sentry, Prop_Send, "m_vecMaxs", m_vecMaxsMini);
		}
		else if (disposable)
		{
			SetEntProp(sentry, Prop_Send, "m_bDisposableBuilding", 1);
			DispatchSpawn(sentry);
			
			SetVariantInt(100);
			AcceptEntityInput(sentry, "SetHealth");
			
			SetEntPropFloat(sentry, Prop_Send, "m_flModelScale", 0.60);
			SetEntPropVector(sentry, Prop_Send, "m_vecMins", m_vecMinsDisp);
			SetEntPropVector(sentry, Prop_Send, "m_vecMaxs", m_vecMaxsDisp);
		}
		else
		{
			SetEntProp(sentry, Prop_Send, "m_nSkin", view_as<int>(team) - 2);
			DispatchSpawn(sentry);
		}
	}
	
	return sentry;
}

void VectorAddRotatedOffset(const float angle[3], float buffer[3], const float offset[3])
{
    float vecForward[3]; float vecLeft[3]; float vecUp[3];
    GetAngleVectors(angle, vecForward, vecLeft, vecUp);

    ScaleVector(vecForward, offset[0]);
    ScaleVector(vecLeft, offset[1]);
    ScaleVector(vecUp, offset[2]);

    float vecAdd[3];
    AddVectors(vecAdd, vecForward, vecAdd);
    AddVectors(vecAdd, vecLeft, vecAdd);
    AddVectors(vecAdd, vecUp, vecAdd);

    AddVectors(buffer, vecAdd, buffer);
}

void ShowBossInfoMenu(int client, int boss)
{
	char sTitle[64];
	FormatEx(sTitle, sizeof(sTitle), "Boss Information: %s", g_Bosses[boss].name);

	Panel panel = new Panel();
	panel.SetTitle(sTitle);

	panel.DrawText(g_Bosses[boss].description);
	panel.DrawItem("Exit");

	panel.Send(client, MenuHandler_Void, MENU_TIME_FOREVER);
}

public int MenuHandler_Void(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_End:
			delete menu;
	}
}