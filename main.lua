local Device = require("device")
local InputContainer = require("ui/widget/container/inputcontainer")
local NetworkMgr = require("ui/network/manager")
local _ = require("gettext")

local showChatGPTDialog = require("dialogs")
local UpdateChecker = require("update_checker")

local AskGPT = InputContainer:new {
  name = "askgpt",
  is_doc_only = true,
}

-- Flag to ensure the update message is shown only once per session
local updateMessageShown = false

function AskGPT:init()
  self.ui.highlight:addToHighlightDialog("askgpt_ChatGPT", function(_reader_highlight_instance)
    return {
      text = _("Ask ChatGPT"),
      enabled = Device:hasClipboard(),
      callback = function()
        NetworkMgr:runWhenOnline(function()
          if not updateMessageShown then
            UpdateChecker.checkForUpdates()
            updateMessageShown = false -- Set flag to true so it won't show again
          end
          showChatGPTDialog(self.ui, _reader_highlight_instance.selected_text.text)
        end)
      end,
    }
  end)
end

function AskGPT:onDictButtonsReady(dict_popup, buttons)
  if dict_popup.is_wiki_fullpage then
      return
  end

  table.insert(buttons, 1, {{
    id = "askgpt",
    text = _("Ask ChatGPT"),
    font_bold = false,
    callback = function()
      NetworkMgr:runWhenOnline(function()
        if not updateMessageShown then
          UpdateChecker.checkForUpdates()
          updateMessageShown = false -- Set flag to true so it won't show again
        end
        showChatGPTDialog(self.ui, dict_popup.lookupword)
      end)
      dict_popup:onClose()
    end
  }})
end

return AskGPT
