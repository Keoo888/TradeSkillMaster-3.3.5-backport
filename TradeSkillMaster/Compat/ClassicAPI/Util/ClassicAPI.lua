--! WotLK fix: this file no longer opts out when the standalone !!!ClassicAPI addon is installed --
--! see the header of _Prelude.lua for why the layer stopped skipping wholesale. What that costs here
--! is spelled out below: a private tooltip under our own name, and a bootstrap that drives only our
--! own listener.
local Private = __TSM_ClassicAPI_Private

-- Texture Path
Private.TEXTURE_PATH = "Interface\\AddOns\\!!!ClassicAPI\\Texture\\"

-- Scan Tooltip
--! WotLK fix: the frame used to be named "CAPI_ScanTooltip", which is also the name the standalone
--! addon gives its own scan tooltip. While the layer opted out wholesale that could never collide;
--! now that this file always loads, it would. CreateFrame does not refuse a name that is taken -- it
--! quietly takes over the global, and the `$parent` in the font-string names below resolves against
--! the frame's name, so two frames under one name would publish font strings under one set of global
--! names (_G["<name>TextLeft2"], the 3.3.5a idiom, FrameXML GameTooltip.lua:126). One copy would then
--! set text on its own tooltip and read it back off the other's. Hence our own name, taken from
--! _Prelude so the readers in C_Container.lua / C_Item.lua / C_Spell.lua can build it the same way.
local Tooltip = CreateFrame("GameTooltip", Private.TooltipName)
Tooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
Tooltip:AddFontStrings(Tooltip:CreateFontString("$parentTextLeft1", nil, "GameTooltipText"), Tooltip:CreateFontString("$parentTextRight1", nil, "GameTooltipText"))
Private.Tooltip = Tooltip

-- General Event
Tooltip:SetScript("OnEvent", function(Self, Event)
	--! WotLK fix: this used to drive the GLOBAL ItemEventListener. With the standalone installed that
	--! global is theirs, their own bootstrap has already called Init() -- and Init() deletes itself
	--! (`self.Init = nil`, ItemUtil.lua) -- so a second call is "attempt to call method 'Init' (a nil
	--! value)". Ours lives in Private and is published by ItemUtil.lua, which still opts out when the
	--! standalone is present; when it opted out there is nothing of ours to start, and starting theirs
	--! a second time is not our business either way.
	local Listener = Private.ItemEventListener
	if ( Listener ) then
		-- [Unit.lua:C_UnitInRange] Force client to cache Vial of the Sunwell
		if ( WOW_PROJECT_ID_RCE ~= WOW_PROJECT_CLASSIC ) then
			local _, RangeItemCached = GetItemInfo(34471)
			if ( not RangeItemCached ) then
				Listener:AddCallback(34471, Private.Void)
			end
		end

		Listener:Init()
	end

	Self:UnregisterEvent(Event)
	Self:SetScript("OnEvent", nil)
end)
Tooltip:RegisterEvent("PLAYER_ENTERING_WORLD")

-- Common Functions
function Private.Void()
	-- To the nether!
end

function Private.True()
	return true
end

function Private.False()
	return false
end

function Private.Zero()
	return 0
end

--[[ SAFETY STUBS ]]
-- Modern API namespaces that do not exist on 3.3.5a. TSM only reaches these
-- through short-circuit guards today, but defining inert stubs removes the
-- fragility if any call site forgets the guard. We never override an existing
-- definition (standalone !!!ClassicAPI addon or a real namespace), and we reuse
-- the shared Private.* helpers so return types stay consistent.
--! WotLK fix: these two stubs are ours, the standalone has neither -- so while this file opted out
--! wholesale, the coexistence case was the one WITHOUT them. They are fill-only and now always run.

-- C_PetJournal.GetNumPets() -> numPets, numOwned. No pet journal on 3.3.5a.
_G.C_PetJournal = _G.C_PetJournal or {}
if ( not _G.C_PetJournal.GetNumPets ) then
	_G.C_PetJournal.GetNumPets = function() return 0, 0 end
end

-- C_Seasons.HasActiveSeason() -> bool. WotLK realms are never seasonal.
_G.C_Seasons = _G.C_Seasons or {}
if ( not _G.C_Seasons.HasActiveSeason ) then
	_G.C_Seasons.HasActiveSeason = Private.False
end

--[[ MISCELLANEOUS ]]

-- [LFD_ERROR_FIX] Workaround long-standing client/server error.
--! WotLK fix: guarded by the coexistence flag rather than by the old whole-file early return. The
--! unregisters are idempotent, but HookScript is not: with the standalone installed the hook is
--! already on LFDQueueFrame, and adding a second one would run
--! LFDQueueFrameRandomCooldownFrame_Update twice on every OnShow. This is the one place in the file
--! where the neighbour's work is genuinely the same work, so we skip ours instead of repeating it.
if ( not __TSM_ClassicAPI_SKIP ) then
	local LFDCooldown = LFDQueueFrameCooldownFrame
	if ( LFDCooldown ) then
		LFDCooldown:UnregisterEvent("UNIT_AURA")
		LFDCooldown:UnregisterEvent("PARTY_MEMBERS_CHANGED")
		LFDQueueFrame:HookScript("OnShow", LFDQueueFrameRandomCooldownFrame_Update)
	end
end
