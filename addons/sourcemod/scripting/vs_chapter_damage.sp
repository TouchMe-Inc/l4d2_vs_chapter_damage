#pragma semicolon              1
#pragma newdecls               required

#include <sourcemod>
#include <sdktools>
#include <colors>


public Plugin myinfo = {
    name        = "VersusChapterDamage",
    author      = "TouchMe",
    description = "Shows damage done by teams",
    version     = "build_0006",
    url         = "https://github.com/TouchMe-Inc/l4d2_vs_chapter_damage"
};


/*
 * Gamemode.
 */
#define GAMEMODE_VERSUS         "versus"
#define GAMEMODE_VERSUS_REALISM "mutation12"

/*
 * Team.
 */
#define TEAM_SURVIVOR           2

/*
 * Game rule team.
 */
#define TEAM_A                  0
#define TEAM_B                  1

/*
 * Round.
 */
#define ROUND_FIRST             1
#define ROUND_SECOND            2

// Other
#define TRANSLATIONS            "vs_chapter_damage.phrases"


bool g_bGamemodeAvailable = false;

bool g_bRoundStarted = false;

int g_iTeamDeadPlayers[2] = {0, ...};

ConVar
    g_cvSurvivorLimit = null, /**< survivor_limit */
    g_cvGameMode = null, /**< mp_gamemode */
    g_cvTieBreak = null /**< vs_tiebreak_bonus */
;


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
    if (GetEngineVersion() != Engine_Left4Dead2)
    {
        strcopy(sErr, iErrLen, "Plugin only supports Left 4 Dead 2");
        return APLRes_SilentFailure;
    }

    return APLRes_Success;
}

public void OnPluginStart()
{
    LoadTranslations(TRANSLATIONS);

    g_cvSurvivorLimit = FindConVar("survivor_limit");
    g_cvGameMode = FindConVar("mp_gamemode");
    g_cvTieBreak = FindConVar("vs_tiebreak_bonus");

    char sGameMode[16];
    GetConVarString(g_cvGameMode, sGameMode, sizeof(sGameMode));
    g_bGamemodeAvailable = IsVersusMode(sGameMode);

    HookConVarChange(g_cvGameMode, OnGamemodeChanged);

    HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
    HookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);

    RegConsoleCmd("sm_dmg", Cmd_Dmg);
}

public void OnMapStart() {
    g_iTeamDeadPlayers[TEAM_A] = g_iTeamDeadPlayers[TEAM_B] = 0;
}

/**
 * Called when a gamemode value is changed.
 */
public void OnGamemodeChanged(ConVar hConVar, const char[] sOldGameMode, const char[] sNewGameMode) {
    g_bGamemodeAvailable = IsVersusMode(sNewGameMode);
}

void Event_RoundStart(Event hEvent, const char[] sEventName, bool bDontBroadcast) {
    g_bRoundStarted = true;
}

/**
 * Handles the end of the round event.
 */
void Event_RoundEnd(Event hEvent, const char[] sEventName, bool bDontBroadcast)
{
    if (!g_bRoundStarted) {
        return;
    }

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

    g_iTeamDeadPlayers[InSecondHalfOfRound() ? TEAM_B : TEAM_A] = GetConVarInt(g_cvSurvivorLimit) - iAliveSurvivor;

    g_bRoundStarted = false;
}

public Action Cmd_Dmg(int iClient, int args)
{
    if (g_bGamemodeAvailable == false) {
        return Plugin_Continue;
    }

    char szChapterResult[128];

    if (!InSecondHalfOfRound())
    {
        FormatChapterResult(szChapterResult, sizeof(szChapterResult), iClient, ROUND_FIRST);
        CReplyToCommand(iClient, "%T%s", "TAG", iClient, szChapterResult);
    }

    else
    {
        CReplyToCommand(iClient, "%T%T", "BRACKET_START", iClient, "TAG", iClient);

        FormatChapterResult(szChapterResult, sizeof(szChapterResult), iClient, ROUND_FIRST);
        CReplyToCommand(iClient, "%T%s", "BRACKET_MIDDLE", iClient, szChapterResult);

        FormatChapterResult(szChapterResult, sizeof(szChapterResult), iClient, ROUND_SECOND);
        if (g_iTeamDeadPlayers[TEAM_A] > 0)
        {
            CReplyToCommand(iClient, "%T%s", "BRACKET_END", iClient, szChapterResult);
        }
        else
        {
            CReplyToCommand(iClient, "%T%s", "BRACKET_MIDDLE", iClient, szChapterResult);

            int iRoundFirst = GetRoundDamage(ROUND_FIRST);
            int iRoundSecond = GetRoundDamage(ROUND_SECOND);

            if (iRoundFirst > iRoundSecond) {
                CReplyToCommand(iClient, "%T%T", "BRACKET_END", iClient, "DAMAGE_DIFF", iClient, iRoundFirst - iRoundSecond);
            } else {
                CReplyToCommand(iClient, "%T%T", "BRACKET_END", iClient, "TEABREAK_BONUS", iClient, GetConVarInt(g_cvTieBreak));
            }
        }

    }

    return Plugin_Handled;
}

/**
 * Formats the chapter result message for the client.
 *
 * @param szMessage Buffer to store the formatted message.
 * @param iLength Maximum length of the message.
 * @param iClient Client ID for whom the message is being formatted.
 * @param iRound Current round (first or second).
 */
void FormatChapterResult(char[] szMessage, int iLength, int iClient, int iRound)
{
    // Get the damage dealt by the team in the current chapter.
    int iRoundDamage = GetRoundDamage(iRound);

    // Format the message with the damage information.
    int iOffset = FormatEx(szMessage, iLength, "%T", "ROUND_DAMAGE", iClient, iRound, iRoundDamage);

    // Number of dead players in the team.
    int iTeamDeadPlayers = g_iTeamDeadPlayers[iRound == ROUND_FIRST ? TEAM_A : TEAM_B];

    // Check the number of dead players and add the corresponding information to the message.
    if (iTeamDeadPlayers > 0)
    {
        if (iTeamDeadPlayers >= GetConVarInt(g_cvSurvivorLimit)) {
            FormatEx(szMessage[iOffset], iLength, " %T", "WIPED", iClient);
        } else {
            FormatEx(szMessage[iOffset], iLength, " %T", "HAS_DEAD", iClient, iTeamDeadPlayers);
        }
    }
    
}

int GetRoundDamage(int iRound)
{
    int iFirstTeam = (InSecondHalfOfRound() == AreTeamsFlipped()) ? TEAM_B : TEAM_A;
    int iSecondTeam = iFirstTeam == TEAM_A ? TEAM_B : TEAM_A;

    // Get the damage dealt by the team in the current chapter.
    return GetChapterDamage(iRound == ROUND_FIRST ? iFirstTeam : iSecondTeam);
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
 * Checks if the player is incapacitated.
 *
 * @param iClient The client index.
 * @return True if the player is incapacitated, false otherwise.
 */
bool IsPlayerIncap(int iClient) {
    return view_as<bool>(GetEntProp(iClient, Prop_Send, "m_isIncapacitated"));
}

/**
 * Checks if the player is hanging from or falling from a ledge.
 *
 * @param iClient The client index.
 * @return True if the player is hanging from or falling from a ledge, false otherwise.
 */
bool IsPlayerLedged(int iClient) {
    return view_as<bool>(GetEntProp(iClient, Prop_Send, "m_isHangingFromLedge") | GetEntProp(iClient, Prop_Send, "m_isFallingFromLedge"));
}

/**
 * Checks if the client is a survivor.
 *
 * @param iClient The client index.
 * @return True if the client is a survivor, false otherwise.
 */
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
