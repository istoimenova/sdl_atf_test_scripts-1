---------------------------------------------------------------------------------------------
-- Requirement summary:
-- [Policies] External UCS: PTU without "disallowed_by_external_consent_entities_on" struct
--
-- Description:
-- In case:
-- SDL receives PolicyTableUpdate without “disallowed_by_external_consent_entities_on:
-- [entityType: <Integer>, entityId: <Integer>]” -> of "<functional grouping>"
-- -> from "functional_groupings" section
-- SDL must:
-- a. consider this PTU as valid (with the pre-conditions of all other valid PTU content)
-- b. do not create this "disallowed_by_external_consent_entities_on" field
-- of the corresponding "<functional grouping>" in the Policies database.
--
-- Preconditions:
-- 1. Start SDL (make sure 'disallowed_by_external_consent_entities_on' section is defined in PreloadedPT)
-- 2. Register app1
--
-- Steps:
-- 1. Activate app1
-- 2. Perform PTU (make sure 'disallowed_by_external_consent_entities_on' section is omitted)
-- 3. Verify status of update
-- 4. Register app2
-- 5. Activate app2
-- 6. Verify PTSnapshot
--
-- Expected result:
-- a. PTU finished successfully with UP_TO_DATE status
-- b. Section "disallowed_by_external_consent_entities_on" doesn't exist
--
-- Note: Script is designed for EXTERNAL_PROPRIETARY flow
---------------------------------------------------------------------------------------------

--[[ General configuration parameters ]]
config.deviceMAC = "12ca17b49af2289436f303e0166030a21e525d266e209267433801a8fd4071a0"
config.defaultProtocolVersion = 2

--[[ Required Shared Libraries ]]
local commonFunctions = require('user_modules/shared_testcases/commonFunctions')
local commonSteps = require('user_modules/shared_testcases/commonSteps')
local commonPreconditions = require('user_modules/shared_testcases/commonPreconditions')
local testCasesForExternalUCS = require('user_modules/shared_testcases/testCasesForExternalUCS')

--[[ Local variables ]]
local checkedStatus = "UP_TO_DATE"
local checkedSection = "disallowed_by_external_consent_entities_on"
local grpId = "Location-1"

--[[ General Precondition before ATF start ]]
commonFunctions:SDLForceStop()
commonSteps:DeleteLogsFileAndPolicyTable()
commonPreconditions:BackupFile("sdl_preloaded_pt.json")
testCasesForExternalUCS.removePTS()

local updateFunc = function(preloadedTable)
  preloadedTable.policy_table.functional_groupings[grpId][checkedSection] = {
    {
      entityID = 128,
      entityType = 0
    }
  }
end
testCasesForExternalUCS.updatePreloadedPT(updateFunc)

--[[ General Settings for configuration ]]
Test = require("user_modules/connecttest_resumption")
require('user_modules/AppTypes')

--[[ Preconditions ]]
commonFunctions:newTestCasesGroup("Preconditions")

function Test:ConnectMobile()
  self:connectMobile()
end

function Test:StartSession()
  testCasesForExternalUCS.startSession(self, 1)
end

function Test:RAI_1()
  testCasesForExternalUCS.registerApp(self, 1)
end

--[[ Test ]]
commonFunctions:newTestCasesGroup("Test")

function Test:ActivateApp_1()
  testCasesForExternalUCS.activateApp(self, 1, checkedStatus)
end

function Test:CheckStatus_UP_TO_DATE()
  local reqId = self.hmiConnection:SendRequest("SDL.GetStatusUpdate")
  EXPECT_HMIRESPONSE(reqId, { status = checkedStatus })
end

function Test:CheckPTS()
  if not testCasesForExternalUCS.pts then
    self:FailTestCase("PTS was not created")
  else
    if testCasesForExternalUCS.pts.policy_table.functional_groupings[grpId][checkedSection] == nil then
      self:FailTestCase("Section '" .. checkedSection .. "' was not found in PTS")
    else
      print("Section '".. checkedSection .. "' exists in 'functional_groupings['" .. grpId .. "'] in PTS")
      print(" => OK")
    end
  end
end

function Test.RemovePTS()
  testCasesForExternalUCS.removePTS()
end

function Test:StartSession()
  testCasesForExternalUCS.startSession(self, 2)
end

function Test:RAI_2()
  testCasesForExternalUCS.registerApp(self, 2)
end

function Test:ActivateApp_2()
  testCasesForExternalUCS.activateApp(self, 2)
end

function Test:CheckPTS()
  if not testCasesForExternalUCS.pts then
    self:FailTestCase("PTS was not created")
  else
    if testCasesForExternalUCS.pts.policy_table.functional_groupings[grpId][checkedSection] ~= nil then
      self:FailTestCase("Section '" .. checkedSection .. "' was found in PTS")
    else
      print("Section '".. checkedSection .. "' doesn't exist in PTS")
      print(" => OK")
    end
  end
end

--[[ Postconditions ]]
commonFunctions:newTestCasesGroup("Postconditions")

function Test.StopSDL()
  StopSDL()
end

function Test.RestorePreloadedFile()
  commonPreconditions:RestoreFile("sdl_preloaded_pt.json")
end

return Test
