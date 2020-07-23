local addon_name, global = ...;

function global.MiniWindow(displayed_items, blacklist, settings, start_roll)
  local self = {
    STATUS_ROLL_RUNNING = "rollrunning",
    STATUS_TRADE = "trade",
    STATUS_ROLL_CLOSED = "rollclosed",
    STATUS_SEEN = "seen",

    displayed_items = displayed_items,
    blacklist = blacklist,
    settings = settings,
    start_roll = start_roll,

    lootedMobs = {},
    tradeInfo = nil,
    frame = nil
  }

  if self.settings.shown == nil then
    self.settings.shown = true
  end

  function self.AddToBlacklist(itemLink)
    self.blacklist[itemLink] = true
    for i = #self.displayed_items, 1, -1 do
      if self.blacklist[self.displayed_items[i].itemLink] then
        table.remove(self.displayed_items, i)
      end
    end
  end

  function self.Show()
    self.settings.shown = true
    self.frame:Show()
  end

  function self.Hide()
    self.settings.shown = false
    self.frame:Hide()
  end
  
  function self.CreateFrame()
    local frame = CreateFrame("Frame", addon_name.."MiniWindow", UIParent)
    frame:SetPoint("CENTER",0,0)
    frame:SetWidth(500)
    frame:SetHeight(1)
    frame:SetMovable(true)
    frame:SetFrameStrata("MEDIUM")
    if not self.settings.shown then
      frame:Hide()
    end

    local mover = CreateFrame("Frame", addon_name.."MiniWindowMover", frame)
    mover:SetClampedToScreen(true)
    mover:SetPoint("TOPLEFT",0,0)
    mover:EnableMouse(true)
    mover:SetScript("OnMouseUp", function(frame) frame:GetParent():StopMovingOrSizing() end)
    mover:SetScript("OnMouseDown", function(s, button)
      if button == "RightButton" then
        menu = {
          { text = "Hide", func = function()
              self.Hide()
            end }
          }
          EasyMenu(menu, self.frame.menuFrame, "cursor", 0 , 0, "MENU");
      else
        s:GetParent():StartMoving()
      end
    end)
    frame.mover = mover

    frame.content = {}
    frame.content.items = {}

    local label = mover:CreateFontString()
    label:SetFontObject("GameFontNormal")
    label:SetPoint("LEFT", 0, 0)
    label:SetText(addon_name)
    mover.label = label

    mover:SetWidth(label:GetStringWidth())
    mover:SetHeight(label:GetStringHeight())
    
    local menuFrame = CreateFrame("Frame", addon_name.."RightMenuFrame", UIParent, "UIDropDownMenuTemplate")
    frame.menuFrame = menuFrame

    return frame
  end

  
  function self.Refresh()
    local rollRunning = false
    for i = 1, #self.displayed_items do
      if self.displayed_items[i].status.name == self.STATUS_ROLL_RUNNING then
        rollRunning = true
        break
      end
    end

    local content = self.frame.content
    for i = 1, #self.displayed_items do
      local item = content.items[i]
      if item == nil then
        content.items[i] = CreateFrame("Frame", nil, self.frame)
        item = content.items[i]
        item:SetHeight(20)
        item:SetPoint("RIGHT", self.frame, "RIGHT", 0, 0)
        if i == 1 then
          item:SetPoint("TOPLEFT", self.frame.mover, "BOTTOMLEFT", 0, 0)
        else
          item:SetPoint("TOPLEFT", content.items[i - 1], "BOTTOMLEFT", 0, -2)
        end
        
        item.closeBtn = CreateFrame("Button", nil, item, "UIPanelButtonTemplate")
        item.closeBtn:SetPoint("LEFT", 0, 0)
        item.closeBtn:SetText("X")
        item.closeBtn:SetNormalFontObject("GameFontNormalSmall")
        item.closeBtn:SetHighlightFontObject("GameFontHighlightSmall")
        item.closeBtn:SetWidth(20)
        item.closeBtn:SetHeight(20)
        item.closeBtn:SetScript("onclick", function()
          table.remove(self.displayed_items, i)
          self.Refresh()
        end)
        
        item.action = CreateFrame("Button", addon_name.."Action"..i, item, "UIPanelButtonTemplate")
        item.action:SetNormalFontObject("GameFontNormalSmall")
        item.action:SetHighlightFontObject("GameFontHighlightSmall")
        item.action:SetPoint("LEFT", item.closeBtn, "RIGHT", 0, 0)
        item.action:SetWidth(125)
        item.action:SetHeight(20)
        
        item.name = {}
        item.name.label = item:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        item.name.label:SetPoint("LEFT", item.action, "RIGHT", 5, 0)
        item.name.label:SetPoint("RIGHT", item, "RIGHT", 0, 0)
        item.name.label:SetJustifyH("LEFT")
        item.name.box = CreateFrame("Frame", nil, item)
        item.name.tooltip = CreateFrame('GameTooltip', addon_name.."Tooltip"..i, UIParent, 'GameTooltipTemplate')
        item.name.box:SetScript("OnLeave", function()
          item.name.tooltip:Hide();
        end)
        item.name.box:SetScript("OnMouseDown", function(s, button)
          if button == "RightButton" then
            menu = {
              { text = "Blacklist Item", func = function()
                  self.AddToBlacklist(self.displayed_items[i].itemLink)
                  self.Refresh()
                end }
              }
              EasyMenu(menu, self.frame.menuFrame, "cursor", 0 , 0, "MENU");
          end
        end)
      end
      item:Show()
      
      item.name.label:SetText(self.displayed_items[i].itemLink)
      item.name.box:SetPoint("TOPLEFT", item.name.label, 0, 0)
      item.name.box:SetWidth(item.name.label:GetStringWidth())
      item.name.box:SetHeight(item.name.label:GetStringHeight())
      item.name.box:SetScript("OnEnter", function()
        item.name.tooltip:SetOwner(item.name.label, "ANCHOR_CURSOR", 0, 0)
        item.name.tooltip:SetHyperlink(self.displayed_items[i].itemLink)
      end)

      if self.displayed_items[i].status.name == self.STATUS_SEEN then
        item.action:SetText("Start Roll")
        item.action:SetEnabled(not rollRunning)
        item.action:SetScript("onclick", function()
          self.start_roll(self.displayed_items[i].itemLink, 30)
        end)
      elseif self.displayed_items[i].status.name == self.STATUS_ROLL_RUNNING then
        item.action:SetText("Rolling...")
        item.action:SetEnabled(false)
      elseif self.displayed_items[i].status.name == self.STATUS_ROLL_CLOSED then
        item.action:SetText("Roll again")
        item.action:SetEnabled(not rollRunning)
        item.action:SetScript("onclick", function()
          self.start_roll(self.displayed_items[i].itemLink, 30)
        end)
      elseif self.displayed_items[i].status.name == self.STATUS_TRADE then
        item.action:SetText("Trade "..self.displayed_items[i].status.player)
        item.action:SetEnabled(true)
        item.action:SetScript("onclick", function()
          for j = 1, 40 do
            if GetRaidRosterInfo(j) == self.displayed_items[i].status.player then
              FollowUnit("raid"..j)
              InitiateTrade("raid"..j)
              break
            end
          end
        end)
      end
      
      item.action:SetWidth(item.action:GetFontString():GetStringWidth() + 30)
    end
    for i = #content.items, #self.displayed_items + 1, -1 do
      content.items[i]:Hide()
    end
  end

  function self.OnRollingStarted(itemLink)
    for i = 1, #self.displayed_items do
      if self.displayed_items[i].itemLink == itemLink and self.displayed_items[i].status.name ~= self.STATUS_TRADE then
        self.displayed_items[i].status = { name = self.STATUS_ROLL_RUNNING }
      end
    end
    self.Refresh()
  end
  
  function self.OnRollingClosed(itemLink, winner)
    local awardedAlready = false
    for i = 1, #self.displayed_items do
      if self.displayed_items[i].itemLink == itemLink and self.displayed_items[i].status.name ~= self.STATUS_TRADE then
        if awardedAlready or (not winner) then
          self.displayed_items[i].status = { name = self.STATUS_ROLL_CLOSED, bids = 0 }    
        else
          self.displayed_items[i].status = { name = self.STATUS_TRADE, player = winner }
          awardedAlready = true
        end
      end
    end
    self.Refresh()
  end
  
  function self.OnLootWindowOpened()
    local _,  masterlooterPartyID = GetLootMethod()
    if masterlooterPartyID ~= 0 or GetNumLootItems() == 0 then return end
    if self.lootedMobs[GetLootSourceInfo(1)] then
      return
    end
    
    for i = 1, GetNumLootItems() do 
      local itemLink = GetLootSlotLink(i)
      local lootIcon, lootName, _, _, quality = GetLootSlotInfo(i)
      if quality and quality >= 3 and (not self.blacklist[itemLink]) then
        table.insert(self.displayed_items, {itemLink = itemLink, itemIcon = lootIcon, itemName = lootName, status = { name = self.STATUS_SEEN}})
      end
    end
    
    if GetNumLootItems() > 0 then
      self.Refresh()
      self.lootedMobs[GetLootSourceInfo(1)] = true
    end
  end
  
  function self.OnAcceptUpdate(player, target)
    if (player == 1 or target == 1) then
      self.tradeInfo = { player = {}, target = {} }
      self.tradeInfo.target.name = UnitName("NPC")
  
      for i = 1, 6 do
        local playerLink = GetTradePlayerItemLink(i)
        if playerLink then
          tinsert(self.tradeInfo.player, { itemLink = playerLink })
        end
      end
    else
      self.tradeInfo = nil
    end
  end
  
  function self.OnChatMsg(msg)
    if msg == LE_GAME_ERR_TRADE_COMPLETE and self.tradeInfo then
      local targetPlayer = self.tradeInfo.target.name
      for i = 1, #self.tradeInfo.player do
        local itemLink = self.tradeInfo.player[i].itemLink
        for j = 1, #self.displayed_items do
          if self.displayed_items[j].itemLink == itemLink and self.displayed_items[j].status.name == self.STATUS_TRADE and self.displayed_items[j].status.player == targetPlayer then
            table.remove(self.displayed_items, j)
            self.Refresh()
            break
          end
        end
      end
    end
  end

  function self.RegisterEvents()
    local events = CreateFrame("Frame");
    events:RegisterEvent("TRADE_ACCEPT_UPDATE");
    events:RegisterEvent("UI_INFO_MESSAGE");
    events:RegisterEvent("LOOT_OPENED");
    events:SetScript("OnEvent", function(_, event, ...)
      if event == "TRADE_ACCEPT_UPDATE" then
        self.OnAcceptUpdate(...)
      elseif event == "UI_INFO_MESSAGE" then
        self.OnChatMsg(...)
      elseif event == "LOOT_OPENED" then
        self.OnLootWindowOpened()
      end
    end);
  end

  self.frame = self.CreateFrame()
  self.Refresh()
  self.RegisterEvents()

  return self
end