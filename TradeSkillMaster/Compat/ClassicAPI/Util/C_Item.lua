--! WotLK fix: no SKIP guard -- this file carries two of the backport's fixes (IsLocked below and
--! GetItemInventoryType further down), so opting it out when the standalone !!!ClassicAPI addon is
--! installed handed TSM the unfixed answers back. See _Prelude.lua for the whole picture.
local Private = __TSM_ClassicAPI_Private

local _G = _G
--! WotLK fix: bind our Private.Enum, not _G.Enum. EnumSupport writes __ItemClassInfo/
--! __InventoryTypeInfo into Private.Enum AFTER Publish; with a neighbour owning _G.Enum those
--! tables never reach the global, so GetItem*Info indexed a nil field and killed API.Item's chunk.
local Enum = Private and Private.Enum or Enum
local Type = type
local Number = tonumber
local Match = string.match
local ITEM_SOULBOUND = ITEM_SOULBOUND
local GetInventoryItemID = GetInventoryItemID
local GetContainerItemID = GetContainerItemID
local GetContainerItemInfo = GetContainerItemInfo
local GetInventoryItemLink = GetInventoryItemLink
local GetContainerItemLink = GetContainerItemLink
local IsInventoryItemLocked = IsInventoryItemLocked
local GetInventoryItemTexture = GetInventoryItemTexture
local GetInventoryItemQuality = GetInventoryItemQuality

local Tooltip = Private.Tooltip
-- The scan tooltip's second line, addressed by name -- the 3.3.5a idiom (FrameXML
-- GameTooltip.lua:126). Built once here rather than per call.
local TOOLTIP_LINE_2 = Private.TooltipName.."TextLeft2"

--! WotLK fix: a fresh table, not `C_Item or {}`. With the standalone installed that `or` adopted the
--! neighbour's table and every assignment below overwrote a key of THEIRS -- the opposite of what
--! rule 3 asks. Ours is published through Private.Publish at the bottom instead: TSM reads ours, the
--! neighbour keeps theirs, and a name nobody has claimed still lands in _G.
local C_Item = {}

function C_Item.IsItemDataCachedByID(ItemInfo)
	local _, Cached = C_Item.GetItemInfo(ItemInfo)
	return Cached ~= nil
end

function C_Item.DoesItemExistByID(ItemID)
	return C_Item.GetItemIconByID(ItemID) ~= nil
end

function C_Item.GetItemNameByID(ItemInfo)
	local Name = C_Item.GetItemInfo(ItemInfo)
	return Name
end

function C_Item.RequestLoadItemDataByID(ItemID)
	local Item = Item:CreateFromItemID(ItemID)
	if ( Item ) then
		Item:ContinueOnItemLoad(C_Item.DoesItemExistByID)
	end
end

function C_Item.GetItemInfoInstant(ItemInfo)
	local _, Link, _, _, _, ItemType, ItemSubType, _, EquipLoc, Texture = C_Item.GetItemInfo(ItemInfo)
	local ID = ItemInfo

	if ( Link and Type(ID) == "string" ) then
		ID = Number(Match(Link, "item:(%d+):"))
	end

	return ID, ItemType, ItemSubType, EquipLoc, Texture
end

function C_Item.GetItemSubClassInfo(classID, subClassID)
	local ItemSubType = Enum.__ItemClassInfo[classID]
	ItemSubType = ItemSubType and ItemSubType[subClassID]

	return ItemSubType, (classID == 4 and subClassID >= 0 and subClassID <= 4)
end

function C_Item.GetItemInventorySlotInfo(InventorySlot)
	return Enum.__InventoryTypeInfo[InventorySlot]
end

function C_Item.GetItemInventoryTypeByID(ItemInfo)
	local _, _, _, _, _, _, _, _, EquipLoc = C_Item.GetItemInfo(ItemInfo)
	return Enum.__InventoryTypeIndex[EquipLoc or "INVTYPE_NON_EQUIP"]
end

function C_Item.GetItemQualityByID(ItemInfo)
	local _, _, Quality = C_Item.GetItemInfo(ItemInfo)
	return Quality
end

C_Item.GetItemInfo = GetItemInfo
C_Item.GetItemIconByID = GetItemIcon
C_Item.GetItemCount = GetItemCount

-- ITEMLOCATIONMIXIN RELIANT
function C_Item.GetItemName(ItemLocation)
	return C_Item.GetItemNameByID(C_Item.GetItemID(ItemLocation))
end

function C_Item.IsLocked(ItemLocation)
	local EquipmentSlotIndex, Locked, _ = ItemLocation.equipmentSlotIndex

	if ( EquipmentSlotIndex ) then
		--! WotLK fix: both native sources answer with the 1nil type (codex: IsInventoryItemLocked
		--! isLocked, GetContainerItemInfo locked), so normalising to a boolean must happen exactly
		--! once, at the return. Doing it here as well made the return compare a boolean against
		--! nil, and `false ~= nil` is true: every existing item answered "locked".
		Locked = IsInventoryItemLocked(EquipmentSlotIndex)
	else
		_, _, Locked = GetContainerItemInfo(ItemLocation.bagID, ItemLocation.slotIndex)
	end

	return Locked ~= nil
end

function C_Item.GetItemID(ItemLocation)
	local EquipmentSlotIndex = ItemLocation.equipmentSlotIndex
	if ( EquipmentSlotIndex ) then
		return GetInventoryItemID("player", EquipmentSlotIndex)
	else
		return GetContainerItemID(ItemLocation.bagID, ItemLocation.slotIndex)
	end
end

function C_Item.GetItemIcon(ItemLocation)
	local EquipmentSlotIndex = ItemLocation.equipmentSlotIndex
	if ( EquipmentSlotIndex ) then
		return GetInventoryItemTexture("player", EquipmentSlotIndex)
	else
		local Icon = GetContainerItemInfo(ItemLocation.bagID, ItemLocation.slotIndex)
		return Icon
	end
end

function C_Item.GetItemLink(ItemLocation)
	local EquipmentSlotIndex = ItemLocation.equipmentSlotIndex
	if ( EquipmentSlotIndex ) then
		return GetInventoryItemLink("player", EquipmentSlotIndex)
	else
		return GetContainerItemLink(ItemLocation.bagID, ItemLocation.slotIndex)
	end
end

function C_Item.GetItemQuality(ItemLocation)
	local _, _, Quality = C_Item.GetItemInfo(C_Item.GetItemLink(ItemLocation))
	return Quality
end

function C_Item.GetItemInventoryType(ItemLocation)
	--! WotLK fix: two different numberings were being mixed. `Enum.__InventoryTypeInfo` is keyed by
	--! the inventory TYPE (`Enum.InventoryType.Index*Type`, 0..34) and holds a localised caption,
	--! while `equipmentSlotIndex` is a character SLOT (1..19) — they coincide only by accident. On
	--! top of that the retail function this mirrors answers with the enum number, and the only
	--! consumer (ItemUtil.lua ItemMixin:GetInventoryType) is the retail one. So resolve the item to
	--! its EquipLoc and reuse the by-ID path, exactly as GetItemInventoryTypeByID does; that also
	--! makes the bag branch work, which the slot-only version answered nil for.
	local Link = C_Item.GetItemLink(ItemLocation)
	if ( not Link ) then
		return nil
	end
	return C_Item.GetItemInventoryTypeByID(Link)
end

function C_Item.GetCurrentItemLevel(ItemLocation)
	local _, _, _, ItemLevel = C_Item.GetItemInfo(C_Item.GetItemID(ItemLocation))
	return ItemLevel
end

function C_Item.IsItemDataCached(ItemLocation)
	return C_Item.GetItemLink(ItemLocation) ~= nil
end

function C_Item.IsBound(ItemLocation)
	local EquipmentSlotIndex = ItemLocation.equipmentSlotIndex

	Tooltip:ClearLines()

	if ( EquipmentSlotIndex ) then
		Tooltip:SetInventoryItem("player", EquipmentSlotIndex)
	else
		Tooltip:SetBagItem(ItemLocation.bagID, ItemLocation.slotIndex)
	end

	--! WotLK fix: NumLines() first -- see C_Container.GetContainerItemInfo. The old `if Line` was
	--! never the guard it looked like: the font string exists whether or not the tooltip counts it
	--! (run 14: numLines == 1, TextLeft2 present). Returns a boolean, never nil -- retail's
	--! C_Item.IsBound answers boolean, and a nil answer is a type error in a boolean DB field.
	local Line = Tooltip:NumLines() >= 2 and _G[TOOLTIP_LINE_2] or nil
	return Line ~= nil and Line:GetText() == ITEM_SOULBOUND
end

C_Item.DoesItemExist = C_Item.GetItemID

C_Item.LockItem = Private.Void
C_Item.UnlockItem = Private.Void
C_Item.GetItemGUID = Private.Void
C_Item.LockItemByGUID = Private.Void
C_Item.UnlockItemByGUID = Private.Void

-- Global
--! WotLK fix: Publish instead of a straight `_G.C_Item = C_Item`. Where nobody has the name we take
--! it as before; where the standalone already has it we only add the keys it lacks, and TSM reads ours
--! through Private.C_Item. The three loose names below get the same treatment by hand -- none of them
--! exists on 3.3.5a (codex: NO for all three), so the only owner they can have is a neighbour's copy.
Private.Publish("C_Item", C_Item)
if ( _G.GetItemInfoInstant == nil ) then
	_G.GetItemInfoInstant = C_Item.GetItemInfoInstant
end
if ( _G.GetItemSubClassInfo == nil ) then
	_G.GetItemSubClassInfo = C_Item.GetItemSubClassInfo
end
if ( _G.GetItemInventorySlotInfo == nil ) then
	_G.GetItemInventorySlotInfo = C_Item.GetItemInventorySlotInfo
end