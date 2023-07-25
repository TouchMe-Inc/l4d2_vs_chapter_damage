#pragma semicolon              1
#pragma newdecls               required

#include <sourcemod>
#include <sdktools>
#include <colors>


public Plugin myinfo =
{
	name = "VersusTeamDmg",
	author = "TouchMe",
	description = "Shows damage done by teams",
	version = "build_0001",
	url = "https://github.com/TouchMe-Inc/l4d2_versus_team_dmg"
};


// Gamemode
#define GAMEMODE_VERSUS         "versus"
#define GAMEMODE_VERSUS_REALISM "mutation12"

// Team
#define TEAM_FIRST 1
#define TEAM_SECOND 0

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

public Action Cmd_Dmg(int iClient, int args)
{
	if (g_bGamemodeAvailable == false) {
		return Plugin_Continue;
	}

	int iFirstTeamDmg = GameRules_GetProp("m_iChapterDamage", .element = TEAM_FIRST);
	int iSecondTeamDmg = GameRules_GetProp("m_iChapterDamage", .element = TEAM_SECOND);

	CPrintToChat(iClient, "Round #1: {olive}%d{default} dmg", iFirstTeamDmg);

	if (InSecondHalfOfRound()) {
		CPrintToChat(iClient, "Round #2: {olive}%d{default} dmg", iSecondTeamDmg);
	}

	return Plugin_Continue;
}

/**
 * Checks if the current round is the second.
 *
 * @return                  Returns true if is second round, otherwise false.
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
