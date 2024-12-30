#pragma once

#include "FilesystemLittleFS.h"
#include "JerryScriptIntegration.h"
#include "JSONMsgRouter.h"
#include "Shell.h"
#include "WsprEncoded.h"


class SubsystemUserDefined
{
    using MsgUD = WsprMessageTelemetryExtendedUserDefined<29>;

public:

    SubsystemUserDefined()
    {
        SetupShell();
        SetupJSON();
    }

private:

    string GetFieldDef(const string &slotName)
    {
        string fileName = slotName + ".json";

        string retVal = FilesystemLittleFS::Read(fileName);

        return retVal;
    }

    bool SetFieldDef(const string &slotName, const string &fieldDef)
    {
        bool retVal = false;

        string fileName = slotName + ".json";

        FilesystemLittleFS::Remove(fileName);
        retVal = FilesystemLittleFS::Write(fileName, fieldDef);

        return retVal;
    }

    string GetJavaScript(const string &slotName)
    {
        string fileName = slotName + ".js";

        string retVal = FilesystemLittleFS::Read(fileName);

        return retVal;
    }
    
    bool SetJavaScript(const string &slotName, const string &script)
    {
        bool retVal = false;

        string fileName = slotName + ".js";

        FilesystemLittleFS::Remove(fileName);
        retVal = FilesystemLittleFS::Write(fileName, script);

        return retVal;
    }

    void ShowMessage(MsgUD &msg)
    {
        auto     &fieldDefList    = msg.GetFieldDefList();
        uint16_t  fieldDefListLen = msg.GetFieldDefListLen();

        Log("Field count: ", fieldDefListLen);

        for (int i = 0; i < fieldDefListLen; ++i)
        {
            const auto &fieldDef = fieldDefList[i];

            Log(fieldDef.name, "(", fieldDef.value, "): ", fieldDef.lowValue, ", ", fieldDef.highValue, ", ", fieldDef.stepSize);
        }
    }

    void ShowJavaScript(uint8_t slot)
    {
        string fileName = string{"slot"} + to_string(slot) + ".js";

        string script = FilesystemLittleFS::Read(fileName);

        Log("Script:");
        Log(script);
    }

    void SetupShell()
    {
        Shell::AddCommand("app.ss.ud.show", [this](vector<string> argList){
            vector<MsgUD *> msgList = {
                &msgSlot0_,
                &msgSlot1_,
                &msgSlot2_,
                &msgSlot3_,
                &msgSlot4_,
            };

            string sep;
            for (int i = 0; auto msg : msgList)
            {
                LogNNL(sep);
                Log("Slot", i, ":");
                ShowMessage(*msg);

                LogNL();

                ShowJavaScript(i);

                LogNL();

                sep = "\n";

                ++i;
            }
        }, { .argCount = 0, .help = "subsystem user defined show"});
    }

    void SetupJSON()
    {
        JSONMsgRouter::RegisterHandler("REQ_GET_FIELD_DEF", [this](auto &in, auto &out){
            string name = (const char *)in["name"];

            Log("REQ_GET_FIELD_DEF for ", name);

            string fieldDef = GetFieldDef(name);

            out["type"]     = "REP_GET_FIELD_DEF";
            out["name"]     = name;
            out["fieldDef"] = fieldDef;
        });

        JSONMsgRouter::RegisterHandler("REQ_SET_FIELD_DEF", [this](auto &in, auto &out){
            string name     = (const char *)in["name"];
            string fieldDef = (const char *)in["fieldDef"];

            Log("REQ_SET_FIELD_DEF for ", name);
            Log(fieldDef);

            bool ok = SetFieldDef(name, fieldDef);

            out["type"] = "REP_SET_FIELD_DEF";
            out["name"] = name;
            out["ok"]   = ok;
        });

        JSONMsgRouter::RegisterHandler("REQ_GET_JS", [this](auto &in, auto &out){
            string name = (const char *)in["name"];

            Log("REQ_GET_JS for ", name);

            string script = GetJavaScript(name);

            out["type"]   = "REP_GET_JS";
            out["name"]   = name;
            out["script"] = script;
        });

        JSONMsgRouter::RegisterHandler("REQ_SET_JS", [this](auto &in, auto &out){
            string name   = (const char *)in["name"];
            string script = (const char *)in["script"];

            Log("REQ_SET_JS for ", name);
            Log(script);

            bool ok = SetJavaScript(name, script);

            out["type"] = "REP_SET_JS";
            out["name"] = name;
            out["ok"]   = ok;
        });

        JSONMsgRouter::RegisterHandler("REQ_PARSE_JS", [this](auto &in, auto &out){
            string script = (const char *)in["script"];

            Log("Parsing script");
            Log(script);

            string err;
            JerryScript::UseVM([&]{
                uint64_t timeStart = PAL.Millis();
                err = JerryScript::ParseScript(script);
            });

            Log("Return: ", err);

            bool ok = err == "";

            out["type"]    = "REP_PARSE_JS";
            out["ok"]      = ok;
            out["err"]     = err;
            out["parseMs"] = JerryScript::GetScriptParseDurationMs();
            out["vmOverheadMs"]   = JerryScript::GetVMOverheadDurationMs();
        });
    }

private:

    inline static MsgUD msgSlot0_;
    inline static MsgUD msgSlot1_;
    inline static MsgUD msgSlot2_;
    inline static MsgUD msgSlot3_;
    inline static MsgUD msgSlot4_;
};