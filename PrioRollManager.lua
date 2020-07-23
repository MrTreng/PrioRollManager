local addon_name, global = ...;

function split(inputstr, sep)
  sep = sep or '%s'
  local t = {}
  for field,s in string.gmatch(inputstr, "([^"..sep.."]*)("..sep.."?)") do
    table.insert(t,field)
    if s == "" then
      return t
    end
  end
end

local function PrioRollManager()
  local self = {
    timer = nil,
    posted_item = nil,
    rolls = {},
    members = {},
    mini_window = nil
  }

  function self.SendAnnounce(msg)
    local target = 'PARTY'
    if IsInRaid() then
      if UnitIsGroupLeader('player') or UnitIsGroupAssistant('player') then
        target = 'RAID_WARNING'
      else
        target = 'RAID'
      end
    end
    SendChatMessage(msg, target, nil, nil)
  end

  function self.SendMessage(msg)
    local target = 'PARTY'
    if IsInRaid() then
      target = 'RAID'
    end

    SendChatMessage(msg, target, nil, nil)
  end
  
  function self.GetSortedRolls()
    local ret = {}

    for upper_bound, ub_rolls in pairs(self.rolls) do
      local rolls_array = {}
      for name, roll in pairs(ub_rolls) do
        table.insert(rolls_array, {name=name, roll=roll})
      end
      table.sort(rolls_array, function (a, b) return a.roll > b.roll end)
      table.insert(ret, {upper_bound=upper_bound, rolls=rolls_array})
    end
    table.sort(ret, function (a, b) return a.upper_bound > b.upper_bound end)

    local winners = {}
    if #ret > 0 then
      for i = 1, #ret[1].rolls do
        if #winners == 0 or ret[1].rolls[i].roll == winners[1].roll then
          table.insert(winners, ret[1].rolls[i])
        end
      end
    end

    return ret, winners
  end
  
  function self.FinishRoll()
    local sorted_member_rolls, winners = self.GetSortedRolls()
  
    if #winners == 0 then
      self.SendMessage('{rt7} Nobody rolled for '..self.posted_item..'!')
      self.mini_window.OnRollingClosed(self.posted_item, nil)
    elseif #winners == 1 then
      self.SendMessage('{rt4} '..winners[1].name..' wins '..self.posted_item..' with a '..winners[1].roll..' out of '..sorted_member_rolls[1].upper_bound)
      self.mini_window.OnRollingClosed(self.posted_item, winners[1].name)
    else
      local tied_rollers = '{rt6} Tie:'
      for i = 1, #winners do
        tied_rollers = tied_rollers..' '..winners[i].name
      end
  
      self.SendMessage(tied_rollers..' ('..winners[1].roll..' out of '..sorted_member_rolls[1].upper_bound..')')
      self.mini_window.OnRollingClosed(self.posted_item, nil)
    end
  
    if #sorted_member_rolls > 0 then
      for i = 1, #sorted_member_rolls do
        while (#sorted_member_rolls[i].rolls > 5) do
          table.remove(sorted_member_rolls[i].rolls, #sorted_member_rolls[i].rolls)
        end
  
        local summary = 'Rolls (out of '..sorted_member_rolls[i].upper_bound..'):'
        for j = 1, #sorted_member_rolls[i].rolls do
          summary = summary .. ' ' .. sorted_member_rolls[i].rolls[j].name .. ' (' .. tostring(sorted_member_rolls[i].rolls[j].roll) .. ')'
        end
  
        self.SendMessage(summary)
      end
    end

    self.posted_item = nil
  end

  function self.CancelRoll()
    self.timer:Cancel()
    self.SendMessage('{rt7} Cancelled roll for '..self.posted_item..'!')
    self.mini_window.OnRollingClosed(self.posted_item, nil)
    self.posted_item = nil
  end
  
  function self.HandleTick()
    local seconds_left = self.timer._remainingIterations - 1

    if seconds_left == 0 then
      self.FinishRoll()
    elseif seconds_left <= 3 or seconds_left == 10 then
      self.SendMessage('{rt1} '..tostring(seconds_left)..' {rt1}')
    end
  end
  
  function self.StartRoll(item_link, duration)
    if not IsInGroup() then
      print('You must be in a group or raid to start a roll!')
      return
    end

    self.posted_item = item_link
    self.rolls = {}
    self.members = {}
    for n = 1, GetNumGroupMembers() do
      local name = GetRaidRosterInfo(n)
      self.members[name] = true
    end
    
    self.mini_window.OnRollingStarted(item_link)
    self.SendAnnounce('Roll now for '..item_link..'! ('..tostring(duration)..' seconds)')
    self.timer = C_Timer.NewTicker(1, self.HandleTick, duration)
  end

  function self.OnChatMsgSystem(msg)
    local name, roll, min, max = msg:match("([^%s]+)..-(%d+)..-(%d+)..-(%d+)")
    roll = tonumber(roll, 10)
    min = tonumber(min, 10)
    max = tonumber(max, 10)
  
    if not name or not roll or not min or not max then
      return
    end
  
    if self.posted_item and self.members[name] and min == 1 and (self.rolls[max] == nil or (not self.rolls[max][name])) then
      if self.rolls[max] == nil then
        self.rolls[max] = {}
      end
      self.rolls[max][name] = roll
    end
  end

  function self.OnAddonLoaded(name)
    if name == addon_name then
      if PRM_DISPLAYED_ITEMS == nil then
        PRM_DISPLAYED_ITEMS = {}
      end
      if PRM_BLACKLIST == nil then
        PRM_BLACKLIST = {}
      end
      if PRM_SETTINGS == nil then
        PRM_SETTINGS = {}
      end
      
      self.mini_window = global.MiniWindow(PRM_DISPLAYED_ITEMS, PRM_BLACKLIST, PRM_SETTINGS, self.StartRoll)
    end
  end
  
  function self.RegisterEvents()
    local frame = CreateFrame('frame')
    frame:RegisterEvent('CHAT_MSG_SYSTEM')
    frame:RegisterEvent('ADDON_LOADED')
    frame:SetScript('OnEvent', function (_, event, ...)
      if event == 'CHAT_MSG_SYSTEM' then
        self.OnChatMsgSystem(...)
      elseif event == 'ADDON_LOADED' then
        self.OnAddonLoaded(...)
      end
    end)
  end
  
  function self.RegisterSlash()
    SLASH_PRM1 = "/prm"
    SLASH_PRM2 = "/priorollmanager"
    SlashCmdList["PRM"] = function (msg)
      local args = split(msg)

      if args[1] == "start" then        
        local _,item_link = GetItemInfo(args[2])
        if item_link then
          if self.posted_item then
            self.CancelRoll()
          end
          local duration = tonumber(args[3]) or 30
          self.StartRoll(item_link, duration)
          return
        end
      end

      if args[1] == 'cancel' then
        if self.posted_item then
          self.CancelRoll()
        else
          print('There is no ongoing roll')
        end
        return
      end

      if args[1] == 'show' then
        self.mini_window.Show()
        return
      end

      if args[1] == 'hide' then
        self.mini_window.Hide()
        return
      end

      print('Usage: /prm start [item] | cancel | show | hide')
    end
  end
  
  self.RegisterEvents()
  self.RegisterSlash()

  return self
end

PrioRollManager()