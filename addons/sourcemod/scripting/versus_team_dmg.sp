#pragma semicolon              1
#pragma newdecls               required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <colors>


public Plugin myinfo =
{
	name = "VersusTeamDmg",
	author = "TouchMe",
	description = "Shows damage done by teams",
	version = "build_0002",
	url = "https://github.com/TouchMe-Inc/l4d2_versus_team_dmg"
};


// Team
#define TEAM_SURVIVOR           2
#define TEAM_INFECTED           3

// Gamemode
#define GAMEMODE_VERSUS         "versus"
#define GAMEMODE_VERSUS_REALISM "mutation12"

// Team
#define TEAM_FIRST              0
#define TEAM_SECOND             1

// Macros
#define IS_VALID_CLIENT(%1)     (%1 > 0 && %1 <= MaxClients)
#define IS_SURVIVOR(%1)         (GetClientTeam(%1) == TEAM_SURVIVOR)
#define IS_INFECTED(%1)         (GetClientTeam(%1) == TEAM_INFECTED)

int
	g_iDamage[2];

bool
	g_bGamemodeAvailable = false;

// Cvars
ConVar
	g_cvGameMode = null;


public void OnPluginStart()
{
	(g_cvGameMode = FindConVar("mp_gamemode")).AddChangeHook(OnGamemodeChanged);

	RegConsoleCmd("sm_dmg", Cmd_Dmg);
}

public void OnMapStart()
{
	g_iDamage[TEAM_FIRST] = 0;
	g_iDamage[TEAM_SECOND] = 0;
}

/**
 * Called when a console variable value is changed.
 *
 * @param convar            Ignored.
 * @param sOldGameMode      Ignored.
 * @param sNewGameMode      String containing new gamemode.
 */
public void OnGamemodeChanged(ConVar hConVar, const char[] sOldGameMode, const char[] sNewGameMode) {
	g_bGamemodeAvailable = IsVersusMode(sNewGameMode);
}

/**
 * Called when the map has loaded, servercfgfile (server.cfg) has been executed, and all
 * plugin configs are done executing. This will always be called once and only once per map.
 * It will be called after OnMapStart().
*/
public void OnConfigsExecuted()
{
	char sGameMode[16];
	GetConVarString(g_cvGameMode, sGameMode, sizeof(sGameMode));
	g_bGamemodeAvailable = IsVersusMode(sGameMode);
}

public Action Cmd_Dmg(int iClient, int iArgs)
{
	if (g_bGamemodeAvailable == false) {
		return Plugin_Continue;
	}

	CPrintToChat(iClient, "Round #1: {olive}%d{default} dmg", g_iDamage[TEAM_FIRST]);

	if (InSecondHalfOfRound()) {
		CPrintToChat(iClient, "Round #2: {olive}%d{default} dmg", g_iDamage[TEAM_SECOND]);
	}

	return Plugin_Continue;
}

public void OnClientPutInServer(int iClient)
{
	SDKHook(iClient, SDKHook_OnTakeDamage, OnTakeDamage);
}

public void OnClientDisconnect(int iClient)
{
	SDKUnhook(iClient, SDKHook_OnTakeDamage, OnTakeDamage);
}

public Action OnTakeDamage(int iVictim, int &iAttacker, int &iInflictor, float &fDamage, int &iDamageType)
{
	if (!IS_VALID_CLIENT(iVictim) || !IsClientInGame(iVictim) || !IS_SURVIVOR(iVictim)) {
		return Plugin_Continue;
	}

	if (IS_VALID_CLIENT(iAttacker) && IsClientInGame(iAttacker) && IS_INFECTED(iAttacker)) {
		g_iDamage[InSecondHalfOfRound() ? TEAM_SECOND : TEAM_FIRST] += RoundFloat(fDamage);
	}

	return Plugin_Continue;
}

/**
 * Checks if the current round is the second.
 */
bool InSecondHalfOfRound() {
	return view_as<bool>(GameRules_GetProp("m_bInSecondHalfOfRound"));
}

/**
 * Is the game mode versus.
 *
 * @param sGameMode         A string containing the name of the game mode.
 *
 * @return                  Returns true if versus, otherwise false.
 */
bool IsVersusMode(const char[] sGameMode) {
	return (StrEqual(sGameMode, GAMEMODE_VERSUS, false) || StrEqual(sGameMode, GAMEMODE_VERSUS_REALISM, false));
}
