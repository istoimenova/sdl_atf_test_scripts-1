---------------------------------------------------------------------------------------------
-- Requirement summary:
-- [Policies]: GetUserFriendlyMessage Local PT does not contain section of requested language value
-- [HMI API] SDL.GetUserFriendlyMessage request/response
--
-- Description:
-- 1. Precondition: stop SDL, backup sdl_preloaded_pt.json, rewrite sdl_preloaded_pt.json with PTU_GetUserFriendlyMessage_without_DE_DE.json.
-- 2. Steps: Start SDL, Activate App, in SDL.GetUserFriendlyMessage parameter language = "de-de".
--
-- Expected result:
--    HMI->SDL: SDL.GetUserFriendlyMessage ("messageCodes": "AppPermissions")
--    SDL->HMI: SDL.GetUserFriendlyMessage ("messages": {messageCode: "AppPermissions", ttsString: "%appName% is requesting the use of the following ....", line1: "Grant Requested", line2: "Permission(s)?"})
---------------------------------------------------------------------------------------------
 
--[[ General configuration parameters ]]
config.deviceMAC = "12ca17b49af2289436f303e0166030a21e525d266e209267433801a8fd4071a0"
 
--[[ Required Shared libraries ]]
local commonFunctions = require ('user_modules/shared_testcases/commonFunctions')
local commonSteps = require('user_modules/shared_testcases/commonSteps')
local commonPreconditions = require('user_modules/shared_testcases/commonPreconditions')
local testCasesForBuildingSDLPolicyFlag = require('user_modules/shared_testcases/testCasesForBuildingSDLPolicyFlag')
local testCasesForPolicyTable = require('user_modules/shared_testcases/testCasesForPolicyTable')

--[[ General Precondition before ATF start ]]
testCasesForBuildingSDLPolicyFlag:Update_PolicyFlag("EXTENDED_POLICY", "EXTERNAL_PROPRIETARY")
testCasesForBuildingSDLPolicyFlag:CheckPolicyFlagAfterBuild("EXTENDED_POLICY","EXTERNAL_PROPRIETARY")
commonSteps:DeleteLogsFileAndPolicyTable()

--ToDo(vvvakulenko): Should be removed when issue: "ATF does not stop HB timers by closing session and connection" is fixed
config.defaultProtocolVersion = 2

--[[ General Settings for configuration ]]
Test = require('connecttest')
require('cardinalities')
local mobile_session = require('mobile_session')

--[[ Preconditions ]]
commonFunctions:newTestCasesGroup("Preconditions")

function Test.Precondition_StopSDL()
  StopSDL()
end

commonPreconditions:BackupFile("sdl_preloaded_pt.json")

testCasesForPolicyTable:Precondition_updatePolicy_By_overwriting_preloaded_pt("files/PTU_GetUserFriendlyMessage_without_DE_DE.json")
  
function Test.Precondition_StartSDL()
  StartSDL(config.pathToSDL, config.ExitOnCrash)
end

function Test:Precondtion_initHMI()
  self:initHMI()
end

function Test:Precondtion_initHMI_onReady()
  self:initHMI_onReady()
end

function Test:Precondtion_initHMI_onReady()
  self:connectMobile()
end

function Test:Precondtion_CreateSession()
  self.mobileSession = mobile_session.MobileSession(self, self.mobileConnection)
  self.mobileSession:StartService(7)
end
 
--[[ Test ]]
commonFunctions:newTestCasesGroup("Test")

function Test:TestStep_ActivateApp_language_section_in_localPT()
  local request_id = self.hmiConnection:SendRequest("SDL.ActivateApp", { appID = self.applications["Test Application"]})
  EXPECT_HMIRESPONSE(request_id)
  :Do(function(_,data)
    if data.result.isSDLAllowed ~= true then
      local request_id_get_user_friendly_message = self.hmiConnection:SendRequest("SDL.GetUserFriendlyMessage", {language = "de-de", messageCodes = {"AppPermissions"}})
      --ToDo(vvvakulenko): Uncomment after resolving APPLINK-16094
      --EXPECT_HMIRESPONSE(request_id_get_user_friendly_message,{result = {code = 0, method = "SDL.GetUserFriendlyMessage",
      --messages = {{line1 = "Grant Requested", line2 = "Permission(s)?", messageCode = "AppPermissions", textBody = "%appName% is requesting the use of the following vehicle information and permissions: %functionalGroupLabels%. \n\nIf you press yes, you agree that %vehicleMake% will not be liable for any damages or loss of privacy related to %appName%’s use of your data. You can change these permissions and hear detailed descriptions in the mobile apps settings menu."}}}})
      EXPECT_HMIRESPONSE(request_id_get_user_friendly_message)
      :Do(function(_,_)
        self.hmiConnection:SendNotification("SDL.OnAllowSDLFunctionality",
        {allowed = true, source = "GUI", device = {id = config.deviceMAC, name = "127.0.0.1"}})
        EXPECT_HMICALL("BasicCommunication.ActivateApp")
        :Do(function(_,_)
          self.hmiConnection:SendResponse(data.id,"BasicCommunication.ActivateApp", "SUCCESS", {})
        end)
        :Times(2)
      end)
    end
  end)   
  EXPECT_NOTIFICATION("OnHMIStatus", {hmiLevel = "FULL", systemContext = "MAIN"})
end
 
--[[ Postconditions ]]
commonFunctions:newTestCasesGroup("Postconditions")

function Test:Postcondition_Force_Stop_SDL()
  commonFunctions:SDLForceStop(self)
end

return Test