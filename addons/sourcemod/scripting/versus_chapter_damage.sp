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
#define TEAM_SURVIVOR           2

// Game Rule Team
#define TEAM_A 0
#define TEAM_B 1

// Macros
#define IS_SURVIVOR(%1)         (GetClientTeam(%1) == TEAM_SURVIVOR)

// Other
#define TRANSLATIONS            "versus_chapter_damage.phrases"

bool
	g_bGamemodeAvailable = false,
	g_bTeamWiped[2] = {false, false};

// Cvars
ConVar
	g_cvGameMode = null;


/**
 * Called before OnPluginStart.
 *
 * @param myself      Handle to the plugin
 * @param bLate       Whether or not the plugin was loaded "late" (after map load)
 * @param sErr        Error message buffer in case load failed
 * @param iErrLen     Maximum number of characters for error message buffer
 * @return            APLRes_Success | APLRes_SilentFailure
 */
public APLRes AskPluginLoad2(Handle myself, bool bLate, char[] sErr, int iErrLen)
{
	EngineVersion engine = GetEngineVersion();

	if (engine != Engine_Left4Dead2) {
		strcopy(sErr, iErrLen, "Plugin only supports Left 4 Dead 2");
		return APLRes_SilentFailure;
	}

	return APLRes_Success;
}

/**
 * Loads dictionary files. On failure, stops the plugin execution.
 */
void InitTranslations()
{
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, PLATFORM_MAX_PATH, "translations/" ... TRANSLATIONS ... ".txt");

	if (FileExists(sPath)) {
		LoadTranslations(TRANSLATIONS);
	} else {
		SetFailState("Path %s not found", sPath);
	}
}

public void OnPluginStart()
{
	InitTranslations();

	HookConVarChange((g_cvGameMode = FindConVar("mp_gamemode")), OnGamemodeChanged);

	HookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);

	RegConsoleCmd("sm_dmg", Cmd_Dmg);
}

public void OnMapStart() {
	g_bTeamWiped[TEAM_A] = g_bTeamWiped[TEAM_B] = false;
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

public void Event_RoundEnd(Event hEvent, const char[] sEventName, bool bDontBroadcast)
{
	int iAliveSurvivor = 0;

	for (int iClient = 1; iClient <= MaxClients; iClient ++)
	{
		if (IsClientInGame(iClient)
		&& IS_SURVIVOR(iClient)
		&& IsPlayerAlive(iClient)
		&& !IsPlayerIncap(iClient)
		&& !IsPlayerLedged(iClient))
		{
			iAliveSurvivor ++;
		}
	}

	g_bTeamWiped[InSecondHalfOfRound() ? TEAM_B : TEAM_A] = iAliveSurvivor > 0 ? false : true;
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

	int iLen = 0;
	char sMessage[192];

	iLen = FormatEx(sMessage, sizeof(sMessage), "%T", "ROUND_DAMAGE", iClient, 1, GetChapterDamage(iFirstTeam));

	if (g_bTeamWiped[TEAM_A]) {
		FormatEx(sMessage[iLen], sizeof(sMessage), " %T", "WIPED", iClient);
	}

	CPrintToChat(iClient, sMessage);

	if (bInSecondHalfOfRound)
	{
		int iSecondTeam = iFirstTeam == TEAM_A ? TEAM_B : TEAM_A;

		iLen = FormatEx(sMessage, sizeof(sMessage), "%T", "ROUND_DAMAGE", iClient, 2, GetChapterDamage(iSecondTeam));

		if (g_bTeamWiped[TEAM_B]) {
			FormatEx(sMessage[iLen], sizeof(sMessage), " %T", "WIPED", iClient);
		}

		CPrintToChat(iClient, sMessage);
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
	return  GameRules_GetProp("m_iChapterDamage", .element = iTeam);
}

bool IsPlayerIncap(int iClient) {
	return view_as<bool>(GetEntProp(iClient, Prop_Send, "m_isIncapacitated"));
}

bool IsPlayerLedged(int iClient) {
	return view_as<bool>(GetEntProp(iClient, Prop_Send, "m_isHangingFromLedge") | GetEntProp(iClient, Prop_Send, "m_isFallingFromLedge"));
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
