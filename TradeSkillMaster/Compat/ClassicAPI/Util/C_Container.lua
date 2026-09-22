--! WotLK fix: no SKIP guard -- GetContainerItemInfo below carries the sixth-native-return fix, and
--! opting the file out when the standalone !!!ClassicAPI addon is installed handed TSM the unfixed
--! answer back (hasLoot hardcoded to false). See _Prelude.lua for the whole picture.
local Private = __TSM_ClassicAPI_Private

local _G = _G
local ITEM_SOULBOUND = ITEM_SOULBOUND
local GetContainerItemInfo = GetContainerItemInfo

--! WotLK fix: a fresh table, not `C_Container or {}` -- that `or` adopted the neighbour's table and
--! wrote our keys over theirs. Published through Private.Publish at the bottom instead.
local C_Container = {}

local Tooltip = Private.Tooltip
-- The scan tooltip's second line, addressed by name (FrameXML GameTooltip.lua:126). Built once.
local TOOLTIP_LINE_2 = Private.TooltipName.."TextLeft2"

function C_Container.GetContainerItemInfo(ContainerIndex, SlotIndex)
	--! WotLK fix: the sixth native return, `lootable`, was being dropped and hasLoot hardcoded to
	--! false (codex: texture, count, locked, quality, readable, lootable, link). That is a real
	--! source on 3.3.5a — a container item such as a lockbox or a clam. `isFiltered` and
	--! `hasNoValue` have no source on this client, so their false stays, deliberately.
	local Icon, Stack, Locked, Quality, Readable, Lootable = GetContainerItemInfo(ContainerIndex, SlotIndex)

	if ( Icon ) then
		Tooltip:ClearLines()
		Tooltip:SetBagItem(ContainerIndex, SlotIndex)
		--! WotLK fix: NumLines() first. Run 14 measured numLines == 1 on our template-less scan tooltip
		--! while _G[...TextLeft2] existed -- a named font string the tooltip does not count is not a
		--! line, and its text belongs to whatever was set before (TSM-028).
		local Line = Tooltip:NumLines() >= 2 and _G[TOOLTIP_LINE_2] or nil

		return {
			iconFileID = Icon,
			stackCount = Stack,
			isLocked = Locked,
			quality = Quality,
			isReadable = Readable,
			hasLoot = Lootable and true or false,
			hyperlink = C_Container.GetContainerItemLink(ContainerIndex, SlotIndex),
			isFiltered = false,
			hasNoValue = false,
			itemID = C_Container.GetContainerItemID(ContainerIndex, SlotIndex),
			--! WotLK fix: `Line ~= nil and`, not `Line and` -- BagTracking declares isBound as a boolean
			--! field, and a nil Line made the whole `and` chain nil, which Table.lua rejects by type.
			isBound = Line ~= nil and Line:GetText() == ITEM_SOULBOUND
		}
	end
end

function C_Container.GetMaxArenaCurrency()
	return 10000 -- Note: This could differ on servers.
end

function C_Container.PlayerHasHearthstone()
	for ContainerIndex=0,4 do
		local Total = C_Container.GetContainerNumSlots(ContainerIndex)
		if ( Total > 0 ) then
			for SlotIndex=1,Total do
				local ID = C_Container.GetContainerItemID(ContainerIndex, SlotIndex)
				if ( ID == 6948 ) then
					return ID
				end
			end
		end
	end
end

C_Container.GetBagName = GetBagName
C_Container.GetItemCooldown = GetItemCooldown
C_Container.UseContainerItem = UseContainerItem
C_Container.GetContainerItemID = GetContainerItemID
C_Container.SplitContainerItem = SplitContainerItem
C_Container.PickupContainerItem = PickupContainerItem
C_Container.GetContainerItemLink = GetContainerItemLink
C_Container.GetContainerNumSlots = GetContainerNumSlots
C_Container.SetBagPortraitTexture = SetBagPortraitTexture
C_Container.GetContainerNumFreeSlots = GetContainerNumFreeSlots
C_Container.ContainerIDToInventoryID = ContainerIDToInventoryID
C_Container.GetContainerItemDurability = GetContainerItemDurability

C_Container.UseHearthstone = Private.Void
C_Container.IsBattlePayItem = Private.False
C_Container.IsContainerFiltered = Private.False
C_Container.SetBackpackAutosortDisabled = Private.False

-- INCOMPLETE
--[[
C_Container.SortBags
C_Container.SortBankBags
C_Container.SetItemSearch
C_Container.GetBagSlotFlag
C_Container.SetBagSlotFlag
C_Container.SocketContainerItem
C_Container.SortReagentBankBags
C_Container.GetSortBagsRightToLeft
C_Container.SetSortBagsRightToLeft
C_Container.GetBankAutosortDisabled
C_Container.ShowContainerSellCursor
C_Container.SetBankAutosortDisabled
C_Container.GetContainerItemCooldown
C_Container.SetInsertItemsLeftToRight
C_Container.GetContainerItemQuestInfo
C_Container.GetInsertItemsLeftToRight
C_Container.ContainerRefundItemPurchase
C_Container.GetBackpackAutosortDisabled
C_Container.GetContainerItemPurchaseInfo
C_Container.GetContainerItemPurchaseItem
C_Container.GetContainerItemEquipmentSetInfo
C_Container.GetContainerItemPurchaseCurrency
]]

-- Global
--! WotLK fix: Publish rather than a straight assignment, and the loose alias is fill-only -- see the
--! bottom of C_Item.lua for the same shape and the reason.
Private.Publish("C_Container", C_Container)
if ( _G.C_GetContainerItemInfo == nil ) then
	_G.C_GetContainerItemInfo = C_Container.GetContainerItemInfo
end