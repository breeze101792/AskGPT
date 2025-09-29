local InputDialog = require("ui/widget/inputdialog")
local ChatGPTViewer = require("chatgptviewer")
local UIManager = require("ui/uimanager")
local InfoMessage = require("ui/widget/infomessage")
local _ = require("gettext")

local queryChatGPT = require("gpt_query")

local CONFIGURATION = nil
local buttons, input_dialog

local success, result = pcall(function() return require("configuration") end)
if success then
  CONFIGURATION = result
else
  print("configuration.lua not found, skipping...")
end

local function translateText(text, target_language)
  local translation_message = {
    role = "user",
    content = "Translate the following text to " .. target_language .. ": " .. text
  }
  local translation_history = {
    {
      role = "system",
      content = "You are a helpful translation assistant. Provide direct translations without additional commentary."
    },
    translation_message
  }
  return queryChatGPT(translation_history)
end

local function explainText(text, target_language)
  local explanation_message = {
    role = "user",
    content = "Help to analyze this paragraph, explain difficut words/phrase/structure in " .. target_language .. ": " .. text
  }
  local explanation_history = {
    {
      role = "system",
      content = "You are a helpful language teacher. Provide direct translations and explination difficult words/grammar with clear and simple way without extra words."
    },
    explanation_message
  }
  return queryChatGPT(explanation_history)
end

local function researchText(text, target_language)
  local explanation_message = {
    role = "user",
    content = "Help to analyze this paragraph. Use ".. target_language .. " to explain the story/purpose of why the writter said the following things" .. ": " .. text
  }
  local explanation_history = {
    {
      role = "system",
      content = "You are a helpful reading researcher assistant. Provide story behind the sentences without additional commentary."
    },
    explanation_message
  }
  return queryChatGPT(explanation_history)
end

local function dictionaryText(text, target_language, context)
  local explanation_message = {
    role = "user",
    content = "Help to check dictionary for " .. text .. " in following context, and explain in " .. target_language .. ": " .. context
  }
  local explanation_history = {
    {
      role = "system",
      content = "You are a helpful dictionary checker assistant. Provide direct dictionary content with the contex without additional commentary. Also provide more usages/examples for learner to master this word."
    },
    explanation_message
  }
  return queryChatGPT(explanation_history)
end

local function createResultText(highlightedText, message_history)
  local result_text = _("Highlighted text: ") .. "\"" .. highlightedText .. "\"\n\n"

  for i = 3, #message_history do
    if message_history[i].role == "user" then
      result_text = result_text .. _("User: ") .. message_history[i].content .. "\n\n"
    else
      result_text = result_text .. _("ChatGPT: ") .. message_history[i].content .. "\n\n"
    end
  end

  return result_text
end

local function showLoadingDialog()
  local loading = InfoMessage:new{
    text = _("Loading..."),
    timeout = 0.1
  }
  UIManager:show(loading)
end

local function showChatGPTDialog(ui, highlightedText, message_history)
  local title, author =
    ui.document:getProps().title or _("Unknown Title"),
    ui.document:getProps().authors or _("Unknown Author")
  local message_history = message_history or {{
    role = "system",
    content = "The following is a conversation with an AI assistant. The assistant is helpful, creative, clever, and very friendly. Answer as concisely as possible."
  }}

  local prev_context, next_context
  if ui.highlight then
    prev_context, next_context = ui.highlight:getSelectedWordContext(15)
  end
  local full_context = ""
  if prev_context then
    full_context = full_context .. prev_context .. " "
  end
  full_context = full_context .. highlightedText
  if next_context then
    full_context = full_context .. " " .. next_context
  end

  local function handleNewQuestion(chatgpt_viewer, question)
    table.insert(message_history, {
      role = "user",
      content = question
    })

    local answer = queryChatGPT(message_history)

    table.insert(message_history, {
      role = "assistant",
      content = answer
    })

    local result_text = createResultText(highlightedText, message_history)

    chatgpt_viewer:update(result_text)
  end

  buttons = {
    {
      text = _("Cancel"),
      callback = function()
        UIManager:close(input_dialog)
      end
    },
    {
      text = _("Ask"),
      callback = function()
        local question = input_dialog:getInputText()
        UIManager:close(input_dialog)
        showLoadingDialog()

        UIManager:scheduleIn(0.1, function()
          local context_message = {
            role = "user",
            content = "I'm reading something titled '" .. title .. "' by " .. author ..
              ". I have a question about the following highlighted text: " .. highlightedText
          }
          table.insert(message_history, context_message)

          local question_message = {
            role = "user",
            content = question
          }
          table.insert(message_history, question_message)

          local answer = queryChatGPT(message_history)
          local answer_message = {
            role = "assistant",
            content = answer
          }
          table.insert(message_history, answer_message)

          local result_text = createResultText(highlightedText, message_history)

          local chatgpt_viewer = ChatGPTViewer:new {
            title = _("AskGPT"),
            text = result_text,
            onAskQuestion = handleNewQuestion
          }

          UIManager:show(chatgpt_viewer)
        end)
      end
    }
  }

  function_buttons = {}
  if CONFIGURATION and CONFIGURATION.features and CONFIGURATION.features.translate_to then
    table.insert(function_buttons, {
      text = _("Translate"),
      callback = function()
        showLoadingDialog()

        UIManager:scheduleIn(0.1, function()
          local translated_text = translateText(highlightedText, CONFIGURATION.features.translate_to)

          table.insert(message_history, {
            role = "user",
            content = "Translate to " .. CONFIGURATION.features.translate_to .. ": " .. highlightedText
          })

          table.insert(message_history, {
            role = "assistant",
            content = translated_text
          })

          local result_text = createResultText(highlightedText, message_history)
          local chatgpt_viewer = ChatGPTViewer:new {
            title = _("Translation"),
            text = result_text,
            onAskQuestion = handleNewQuestion
          }

          UIManager:show(chatgpt_viewer)
        end)
      end
    })
  end

  if CONFIGURATION and CONFIGURATION.features and CONFIGURATION.features.translate_to then
    table.insert(function_buttons, {
      text = _("Explain"),
      callback = function()
        showLoadingDialog()

        UIManager:scheduleIn(0.1, function()
          local explanation_text = explainText(highlightedText, CONFIGURATION.features.translate_to)

          table.insert(message_history, {
            role = "user",
            content = "Explain this paragraph in " .. CONFIGURATION.features.translate_to .. ": " .. highlightedText
          })

          table.insert(message_history, {
            role = "assistant",
            content = explanation_text
          })

          local result_text = createResultText(highlightedText, message_history)
          local chatgpt_viewer = ChatGPTViewer:new {
            title = _("Explanation"),
            text = result_text,
            onAskQuestion = handleNewQuestion
          }

          UIManager:show(chatgpt_viewer)
        end)
      end
    })
  end

  if CONFIGURATION and CONFIGURATION.features and CONFIGURATION.features.translate_to then
    table.insert(function_buttons, {
      text = _("Research"),
      callback = function()
        showLoadingDialog()

        UIManager:scheduleIn(0.1, function()
          local research_text = researchText(highlightedText, CONFIGURATION.features.translate_to)

          table.insert(message_history, {
            role = "user",
            content = "Explain the background of '" .. highlightedText .. "' in " .. CONFIGURATION.features.translate_to
          })

          table.insert(message_history, {
            role = "assistant",
            content = research_text
          })

          local result_text = createResultText(highlightedText, message_history)
          local chatgpt_viewer = ChatGPTViewer:new {
            title = _("Research"),
            text = result_text,
            onAskQuestion = handleNewQuestion
          }

          UIManager:show(chatgpt_viewer)
        end)
      end
    })
  end

  if CONFIGURATION and CONFIGURATION.features and CONFIGURATION.features.translate_to then
    table.insert(function_buttons, {
      text = _("Dictionary"),
      callback = function()
        showLoadingDialog()

        UIManager:scheduleIn(0.1, function()
          local dictionary_text = dictionaryText(highlightedText, CONFIGURATION.features.translate_to, full_context)

          table.insert(message_history, {
            role = "user",
            content = "Dictionary for " .. highlightedText .. " in " .. CONFIGURATION.features.translate_to .. " with context: " .. full_context
          })

          table.insert(message_history, {
            role = "assistant",
            content = dictionary_text
          })

          local result_text = createResultText(highlightedText, message_history)
          local chatgpt_viewer = ChatGPTViewer:new {
            title = _("Dictionary"),
            text = result_text,
            onAskQuestion = handleNewQuestion
          }

          UIManager:show(chatgpt_viewer)
        end)
      end
    })
  end

  input_dialog = InputDialog:new{
    title = _("Ask a question about the highlighted text"),
    input_hint = _("Type your question here..."),
    input_type = "text",
    buttons = {buttons, function_buttons}
  }
  UIManager:show(input_dialog)
end

return showChatGPTDialog
