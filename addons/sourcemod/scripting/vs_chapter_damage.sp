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
	version = "build_0004",
	url = "https://github.com/TouchMe-Inc/l4d2_vs_chapter_damage"
};


// Gamemode
#define GAMEMODE_VERSUS         "versus"
#define GAMEMODE_VERSUS_REALISM "mutation12"

// Team
#define TEAM_SURVIVOR           2

// Game Rule Team
#define TEAM_A 0
#define TEAM_B 1

// Round
#define ROUND_FIRST 1
#define ROUND_SECOND 2

// Other
#define TRANSLATIONS            "vs_chapter_damage.phrases"


bool g_bGamemodeAvailable = false;

int
	g_iSurvivorLimit = 0,
	g_iTeamDeadPlayers[2] = {0, ...};

// Cvars
ConVar
	g_cvSurvivorLimit = null, /**< survivor_limit */
	g_cvGameMode = null; /**< mp_gamemode */


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

public void OnPluginStart()
{
	LoadTranslations(TRANSLATIONS);

	HookConVarChange((g_cvSurvivorLimit = FindConVar("survivor_limit")), OnSurvivorLimitChanged);
	HookConVarChange((g_cvGameMode = FindConVar("mp_gamemode")), OnGamemodeChanged);

	HookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);

	RegConsoleCmd("sm_dmg", Cmd_Dmg);

	g_iSurvivorLimit = GetConVarInt(g_cvSurvivorLimit);
}

public void OnMapStart() {
	g_iTeamDeadPlayers[TEAM_A] = g_iTeamDeadPlayers[TEAM_B] = 0;
}

/**
 * Called when a console variable value is changed.
 *
 * @param convar            Ignored.
 * @param sOldValue         Ignored.
 * @param sNewValue      S   tring containing new gamemode.
 */
public void OnGamemodeChanged(ConVar hConVar, const char[] sOldGameMode, const char[] sNewGameMode) {
	g_bGamemodeAvailable = IsVersusMode(sNewGameMode);
}

/**
 * Called when a console variable value is changed.
 *
 * @param convar            Ignored.
 * @param sOldValue         Ignored.
 * @param sNewValue      S   tring containing new survivor limit.
 */
public void OnSurvivorLimitChanged(ConVar hConVar, const char[] sOldGameMode, const char[] sNewGameMode) {
	g_iSurvivorLimit = StringToInt(sNewGameMode);
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
	g_iSurvivorLimit = GetConVarInt(g_cvSurvivorLimit);
}

public void Event_RoundEnd(Event hEvent, const char[] sEventName, bool bDontBroadcast)
{
	int iAliveSurvivor = 0;

	for (int iClient = 1; iClient <= MaxClients; iClient ++)
	{
		if (IsClientInGame(iClient)
		&& IsClientSurvivor(iClient)
		&& IsPlayerAlive(iClient)
		&& !IsPlayerIncap(iClient)
		&& !IsPlayerLedged(iClient))
		{
			iAliveSurvivor ++;
		}
	}

	g_iTeamDeadPlayers[InSecondHalfOfRound() ? TEAM_B : TEAM_A] = g_iSurvivorLimit - iAliveSurvivor;
}

public Action Cmd_Dmg(int iClient, int args)
{
	if (g_bGamemodeAvailable == false
	|| !IsValidClient(iClient)) {
		return Plugin_Continue;
	}

	char sBracketStart[16]; FormatEx(sBracketStart, sizeof(sBracketStart), "%T", "BRACKET_START", iClient);
	char sBracketMiddle[16]; FormatEx(sBracketMiddle, sizeof(sBracketMiddle), "%T", "BRACKET_MIDDLE", iClient);
	char sBracketEnd[16]; FormatEx(sBracketEnd, sizeof(sBracketEnd), "%T", "BRACKET_END", iClient);

	char sChapterResult[192];

	if (!InSecondHalfOfRound())
	{
		FormatChapterResult(sChapterResult, sizeof(sChapterResult), iClient, ROUND_FIRST);
		CReplyToCommand(iClient, "%T %s", "TAG", iClient, sChapterResult);
	}

	else
	{
		CReplyToCommand(iClient, "%s%T", sBracketStart, "TAG", iClient);

		FormatChapterResult(sChapterResult, sizeof(sChapterResult), iClient, ROUND_FIRST);
		CReplyToCommand(iClient, "%s%s", sBracketMiddle, sChapterResult);

		FormatChapterResult(sChapterResult, sizeof(sChapterResult), iClient, ROUND_SECOND);
		CReplyToCommand(iClient, "%s%s", sBracketEnd, sChapterResult);
	}

	return Plugin_Handled;
}

void FormatChapterResult(char[] sMessage, int iLength, int iClient, int iRound)
{
	bool bInSecondHalfOfRound = InSecondHalfOfRound();
	bool bAreTeamsFlipped = AreTeamsFlipped();

	int iFirstTeam;

	if (!bInSecondHalfOfRound) {
		iFirstTeam = bAreTeamsFlipped ? TEAM_A : TEAM_B;
	} else {
		iFirstTeam = bAreTeamsFlipped ? TEAM_B : TEAM_A;
	}

	int iSecondTeam = iFirstTeam == TEAM_A ? TEAM_B : TEAM_A;

	int iChapterDamage = GetChapterDamage(iRound == ROUND_FIRST ? iFirstTeam : iSecondTeam);

	int iOffset = FormatEx(sMessage, iLength, "%T", "ROUND_DAMAGE", iClient, iRound, iChapterDamage);

	int iTeamDeadPlayers = g_iTeamDeadPlayers[iRound == ROUND_FIRST ? TEAM_A : TEAM_B];

	if (iTeamDeadPlayers >= g_iSurvivorLimit) {
		FormatEx(sMessage[iOffset], iLength, " %T", "WIPED", iClient);
	} else if (iTeamDeadPlayers) {
		FormatEx(sMessage[iOffset], iLength, " %T", "HAS_DEAD", iClient, iTeamDeadPlayers);
	}
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

bool IsPlayerIncap(int iClient) {
	return view_as<bool>(GetEntProp(iClient, Prop_Send, "m_isIncapacitated"));
}

bool IsPlayerLedged(int iClient) {
	return view_as<bool>(GetEntProp(iClient, Prop_Send, "m_isHangingFromLedge") | GetEntProp(iClient, Prop_Send, "m_isFallingFromLedge"));
}

bool IsValidClient(int iClient) {
	return (iClient > 0 && iClient <= MaxClients);
}

bool IsClientSurvivor(int iClient) {
	return (GetClientTeam(iClient) == TEAM_SURVIVOR);
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
