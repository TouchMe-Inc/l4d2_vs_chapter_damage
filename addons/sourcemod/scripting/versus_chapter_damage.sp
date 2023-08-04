#pragma semicolon              1
#pragma newdecls               required

#include <sourcemod>
#include <sdktools>
#include <colors>


public Plugin myinfo =
{
	name = "VersusChapterDamage",
	author = "TouchMe",
	description = "Shows damage done by teams",
	version = "build_0002",
	url = "https://github.com/TouchMe-Inc/l4d2_versus_team_dmg"
};


// Gamemode
#define GAMEMODE_VERSUS         "versus"
#define GAMEMODE_VERSUS_REALISM "mutation12"

// Team
#define TEAM_A 0
#define TEAM_B 1

bool
	g_bGamemodeAvailable = false;

// Cvars
ConVar
	g_cvGameMode = null;


public void OnPluginStart()
{
	HookConVarChange((g_cvGameMode = FindConVar("mp_gamemode")), OnGamemodeChanged);

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

	bool bInSecondHalfOfRound = InSecondHalfOfRound();
	bool bAreTeamsFlipped = AreTeamsFlipped();

	int iFirstTeam;

	if (!bInSecondHalfOfRound) {
		iFirstTeam = bAreTeamsFlipped ? TEAM_A : TEAM_B;
	} else {
		iFirstTeam = bAreTeamsFlipped ? TEAM_B : TEAM_A;
	}

	CPrintToChat(iClient, "Round #1: {olive}%d{default} dmg", GetChapterDamage(iFirstTeam));

	if (bInSecondHalfOfRound)
	{
		int iSecondTeam = iFirstTeam == TEAM_A ? TEAM_B : TEAM_A;
		CPrintToChat(iClient, "Round #2: {olive}%d{default} dmg", GetChapterDamage(iSecondTeam));
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
 * Checks if team A has swapped places with team B.
 *
 * @return                  Returns true if team A swapped, otherwise false.
 */
bool AreTeamsFlipped() {
	return view_as<bool>(GameRules_GetProp("m_bAreTeamsFlipped"));
}

/**
 * How much damage did the team.
 */
int GetChapterDamage(int iTeam) {
	return GameRules_GetProp("m_iChapterDamage", .element = iTeam);
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
