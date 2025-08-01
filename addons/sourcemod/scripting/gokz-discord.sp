#include <sourcemod>

#include <SteamWorks>
#include <json>
#include <discord>
#include <gokz/core>
#include <record>
#include <autoexecconfig>

#undef REQUIRE_EXTENSIONS
#undef REQUIRE_PLUGIN

#include <gokz/localdb>
#include <gokz/localranks>
#include <gokz/global>
#include <more-stats>

#define REQUIRE_EXTENSIONS
#define REQUIRE_PLUGIN

#include "gokz-discord/globals.sp"
#include "gokz-discord/helpers.sp"
#include "gokz-discord/gokz-forwards.sp"

#pragma newdecls required
#pragma semicolon 1

public Plugin myinfo =
{
	name = "GOKZ Discord",
	author = "zer0.k",
	description = "",
	version = "0.2.0",
	url = "https://github.com/zer0k-z/gokz-discord"
};


public void OnPluginStart()
{
	LoadTranslations("gokz-discord.phrases");
	CreateConVars();
	
	gA_Records = new ArrayList(sizeof(Record));

	InitAnnounceTimer();
	RegConsoleCmd("sm_testdiscord", DiscordInit);

}

static void CreateConVars()
{
	AutoExecConfig_SetFile("gokz-discord", "sourcemod/gokz");
	AutoExecConfig_SetCreateFile(true);
	
	gCV_UseLocalRank = AutoExecConfig_CreateConVar("gokz_discord_use_local", "1", "Whether local ranking is used.", _, true, 0.0, true, 1.0);
	gCV_UseGlobalRank = AutoExecConfig_CreateConVar("gokz_discord_use_global", "1", "Whether global ranking is used.", _, true, 0.0, true, 1.0);
	gCV_AnnounceBonus = AutoExecConfig_CreateConVar("gokz_discord_announce_bonus", "1", "Whether bonus runs are announced.", _, true, 0.0, true, 1.0);
	gCV_ProOnly = AutoExecConfig_CreateConVar("gokz_discord_pro_only", "0", "Only announce pro runs", _, true, 0.0, true, 1.0);

	gCV_MinRankGlobal = AutoExecConfig_CreateConVar("gokz_discord_min_rank_global", "20", "Minimum rank for top time announcement (Global)", _, true, 1.0);
	gCV_MinRankLocal = AutoExecConfig_CreateConVar("gokz_discord_min_rank_local", "10", "Minimum rank for top time announcement (Local)", _, true, 1.0);
	gCV_MinRecordType = AutoExecConfig_CreateConVar("gokz_discord_min_record_type", "5", "Minimum record type for announcement", _, true, 1.0, true, float(RecordType_GlobalProWR));

	gCV_ShowCourse = AutoExecConfig_CreateConVar("gokz_discord_show_course", "1", "Show course id in the announcement", _, true, 0.0, true, 1.0);
	gCV_ShowRunTime = AutoExecConfig_CreateConVar("gokz_discord_show_run_time", "2", "Show run time in the announcement (0 = Disabled, 1 = Enable without Local PB Diff, 2 = Enable with Local PB Diff)", _, true, 0.0, true, 2.0);
	gCV_ShowThumbnail = AutoExecConfig_CreateConVar("gokz_discord_show_thumbnail", "1", "Show thumbnail in the announcement", _, true, 0.0, true, 1.0);
	gCV_ShowRank = AutoExecConfig_CreateConVar("gokz_discord_show_rank", "1", "Show rank in the announcement", _, true, 0.0, true, 1.0);
	gCV_ShowServer = AutoExecConfig_CreateConVar("gokz_discord_show_server", "1", "Show server in the announcement", _, true, 0.0, true, 1.0);
	gCV_ShowTeleports = AutoExecConfig_CreateConVar("gokz_discord_show_teleports", "1", "Show teleport count in the announcement", _, true, 0.0, true, 1.0);
	gCV_ShowTimestamp = AutoExecConfig_CreateConVar("gokz_discord_show_timestamp", "1", "Show timestamp in the announcement", _, true, 0.0, true, 1.0);

	gCV_UseMoreStats = AutoExecConfig_CreateConVar("gokz_discord_use_morestats", "1", "Whether more-stats statistics are used.", _, true, 0.0, true, 1.0);
	gCV_ShowStrafeCount = AutoExecConfig_CreateConVar("gokz_discord_show_strafecount", "1", "Show strafe count in the announcement (more-stats)", _, true, 0.0, true, 1.0);
	gCV_ShowPerfCount = AutoExecConfig_CreateConVar("gokz_discord_show_perfcount", "1", "Show perfect bhops statistics in the announcement (more-stats)", _, true, 0.0, true, 1.0);
	gCV_ShowAirTicks = AutoExecConfig_CreateConVar("gokz_discord_show_airtime", "1", "Show airtime in the announcement (more-stats)", _, true, 0.0, true, 1.0);
	gCV_ShowAASync = AutoExecConfig_CreateConVar("gokz_discord_show_sync_airaccel", "1", "Show air accelerate statistics in the announcement (more-stats)", _, true, 0.0, true, 1.0);
	gCV_ShowVelChangeSync = AutoExecConfig_CreateConVar("gokz_discord_show_sync_velchange", "1", "Show air velocity change statistics in the announcement (more-stats)", _, true, 0.0, true, 1.0);
	gCV_ShowOverlap = AutoExecConfig_CreateConVar("gokz_discord_show_overlap", "1", "Show overlap airstrafe statistics in the announcement (more-stats)", _, true, 0.0, true, 1.0);
	gCV_ShowDeadAir = AutoExecConfig_CreateConVar("gokz_discord_show_deadair", "1", "Show dead airstrafe statistics in the announcement (more-stats)", _, true, 0.0, true, 1.0);
  gCV_ShowBadAngles = AutoExecConfig_CreateConVar("gokz_discord_show_badangles", "1", "Show bad angles airstrafe statistics in the announcement (more-stats)", _, true, 0.0, true, 1.0);
  gCV_ShowScrollStats = AutoExecConfig_CreateConVar("gokz_discord_show_scrollstats", "1", "Show scroll statistics in the announcement (more-stats)", _, true, 0.0, true, 1.0);

  gCV_ReportToken = AutoExecConfig_CreateConVar("gokz_report_token", "", "Authentication token for the report endpoint");
  gCV_ReportURL = AutoExecConfig_CreateConVar("gokz_report_url", "http://127.0.0.1:8080/report", "URL of the HTTP report endpoint");
  gCV_QQGroupNumber = AutoExecConfig_CreateConVar("gokz_qq_group_number", "", "QQ group number for reporting");


  AutoExecConfig_ExecuteFile();
  AutoExecConfig_CleanFile();
}

public void OnAllPluginsLoaded()
{
	if (!LibraryExists("gokz-core"))
	{
		SetFailState("[GOKZ-Discord] Missing required plugin: gokz-core");
	}


	if (LibraryExists("gokz-global"))
	{
		gB_GOKZGlobal = true;
	}
	if (LibraryExists("gokz-localranks"))
	{
		gB_GOKZLocal = true;
	}
	if (LibraryExists("more-stats"))
	{
		gB_MoreStats = true;
	}
}

public void OnLibraryAdded(const char[] name)
{
	if (StrEqual(name, "gokz-global"))
	{
		gB_GOKZGlobal = true;
	}
	if (StrEqual(name, "gokz-localranks"))
	{
		gB_GOKZLocal = true;
	}
	if (StrEqual(name, "more-stats"))
	{
		gB_MoreStats = true;
	}
}

public void OnLibraryRemoved(const char[] name)
{
	if (StrEqual(name, "gokz-global"))
	{
		gB_GOKZGlobal = false;
	}
	if (StrEqual(name, "gokz-localranks"))
	{
		gB_GOKZLocal = false;
	}
	if (StrEqual(name, "more-stats"))
	{
		gB_MoreStats = false;
	}
}

public Action DiscordInit(int client, int argc)
{
	Record record;
	record.Init(client, 1, 133333.37, 0);
	record.InitLocal(GetSteamAccountID(client), 1, 1, GOKZ_GetCoreOption(client, Option_Mode), 0, 133333.37, 0, false, 5.0, 2, 2, false, -5.0, 2, 2);
	record.InitGlobal(client, 1, GOKZ_GetCoreOption(client, Option_Mode), TimeType_Pro, 90, 90, 133333.37);
	record.InitMoreStats(1,2,3,4,5,6,7,8,9,{1,2,3,4,5});
	gA_Records.PushArray(record, sizeof(Record));
	return Plugin_Handled;
}

void InitAnnounceTimer()
{
	CreateTimer(5.0, Timer_CheckRecord, INVALID_HANDLE, TIMER_REPEAT);
}

public Action Timer_CheckRecord(Handle timer)
{
	Record record;
	for (int i = 0; i < gA_Records.Length; i++)
	{
		gA_Records.GetArray(i, record, sizeof(Record));
		if (record.matchedLocal && record.matchedGlobal)
		{
			DiscordAnnounceRecord(record);
			gA_Records.Erase(i);
		}
		else if (record.matchedLocal)
		{
			// Wait for timeout, or don't wait at all if there's no global plugin
			if (!gB_GOKZGlobal || !gCV_UseGlobalRank.BoolValue || record.timestamp + STEAMWORKS_HTTP_TIMEOUT_DURATION < GetTime())
			{
				DiscordAnnounceRecord(record);
				gA_Records.Erase(i);
			}
		}
		else if (record.matchedGlobal)
		{
			// Wait for some duration or don't wait at all if there's no local ranking
			if (!gB_GOKZLocal || !gCV_UseLocalRank.BoolValue || record.timestamp + LOCAL_MAX_WAIT_TIME < GetTime())
			{
				DiscordAnnounceRecord(record);
				gA_Records.Erase(i);
			}
		}
		else if (record.timestamp + IntMax(LOCAL_MAX_WAIT_TIME, STEAMWORKS_HTTP_TIMEOUT_DURATION) < GetTime())
		{
			// This won't ever get announced, erase it
			gA_Records.Erase(i);
		}
	}
}

void DiscordAnnounceRecord(Record record)
{
        int recordType = record.GetRecordType(gCV_MinRankLocal.IntValue, gCV_MinRankGlobal.IntValue);
        if (recordType == RecordType_Default || recordType < gCV_MinRecordType.IntValue)
        {
                return;
        }
        char token[256];
        gCV_ReportToken.GetString(token, sizeof(token));

        char title[64];
        Format(title, sizeof(title), "%T", gC_RecordType_Names[recordType], LANG_SERVER);

        char content[MAX_FIELD_VALUE_LENGTH];
        strcopy(content, sizeof(content), AnnounceContent(record));

        SendReport(token, title, content);
}

static char[] AnnounceContent(Record record)
{
        char value[MAX_FIELD_VALUE_LENGTH];
	gKV_DiscordConfig.Rewind();
	if (!gKV_DiscordConfig.JumpToKey("Content"))
	{
		gKV_DiscordConfig.JumpToKey("Content", true);
		gKV_DiscordConfig.SetString("Content", " ");
		char sFile[PLATFORM_MAX_PATH];
		BuildPath(Path_SM, sFile, sizeof(sFile), "configs/gokz-discord.cfg");
		gKV_DiscordConfig.Rewind();
		gKV_DiscordConfig.ExportToFile(sFile);
		return value;
	}

        gKV_DiscordConfig.GetString("Content", value, sizeof(value));
        DiscordReplaceString(record, value, sizeof(value));
        return value;
}

static void SendReport(const char[] token, const char[] title, const char[] content)
{
     char url[256];
     gCV_ReportURL.GetString(url, sizeof(url));
     Handle request = SteamWorks_CreateHTTPRequest(HTTPMethod_Post, url);
     if (request == INVALID_HANDLE)
     {
             return;
     }

      SteamWorks_SetHTTPRequestHeaderValue(request, "Content-Type", "application/json");

     char group[64];
     gCV_QQGroupNumber.GetString(group, sizeof(group));

     char body[512];
     FormatEx(body, sizeof(body), "{\"token\":\"%s\",\"title\":\"%s\",\"content\":\"%s\",\"send_to\":\"%s\"}", token, title, content, group);
     SteamWorks_SetHTTPRequestRawPostBody(request, "application/json", body, strlen(body));
}

public int OnReportSent(Handle request, bool failure, bool requestSuccessful, EHTTPStatusCode statusCode, any data)
{
        SteamWorks_DestroyHTTPRequest(request);
        return 0;
}
