-- Bundled !!!ClassicAPI fallback loader (TradeSkillMaster).
--
-- This vendored copy exists so TSM is self-contained when the standalone !!!ClassicAPI addon is NOT
-- installed. When that addon IS installed it provides most of the same globals and loads first (the
-- "!!!" prefix sorts it ahead of TSM).
--
--! WotLK fix: the layer used to opt out WHOLESALE when the standalone was present -- this file set
--! __TSM_ClassicAPI_SKIP and all 56 files early-returned on their first line. That is the shape Cell
--! forbids -- an early return of the shape `if PixelUtil then return end` hands the hot path to a
--! neighbour's copy and rolls the backport's own fixes back -- and here it did exactly that. Measured against the
--! installed standalone 1.20: 45 of 57 files are byte-identical, but the diverging ones are diverging
--! BECAUSE this backport fixed defects in them, so with the addon installed TSM was handed the
--! unfixed answers back:
--!   * C_Item.IsLocked -- theirs normalises with `~= nil` twice, so `false ~= nil` is true and every
--!     equipped item answers "locked";
--!   * C_Item.GetItemInventoryType -- theirs returns a LOCALISED CAPTION out of
--!     Enum.__InventoryTypeInfo instead of the enum number, and nil for a bag item;
--!   * C_Container.GetContainerItemInfo -- theirs drops the sixth native return and hardcodes
--!     hasLoot = false, so a lockbox or a clam reads as having no loot;
--!   * C_Timer -- theirs writes a global named `Timer` on the cold path of the pool (a forgotten
--!     `local`), clobbering any neighbour that uses that very common name;
--!   * MailFrame_Show -- theirs replays MAIL_SHOW through MailFrame_OnEvent, which calls
--!     OpenBackpack(), so the player's bags fly open every time TSM opens the mail window.
--
-- The Cell shape instead: fill gaps, never replace someone else's live implementation, and keep the
-- logic whose correctness matters PRIVATE and call it directly. So:
--
--   * `Private` is created ALWAYS, whether or not the standalone is installed. It is an isolated table,
--     never TSM's addon object -- the upstream files capture their private table via `...`, and bundled
--     inside TSM that argument is TSM's addon object, where writing a key trips TSM:NewPackage's
--     `assert(not self[name])`.
--   * `Private.Publish(name, ours)` puts our implementation in `Private` unconditionally, publishes it
--     to `_G` only when nothing is there, and when a foreign table IS there fills in the keys it lacks
--     without touching the ones it has. Other addons keep the implementation they were built against;
--     TSM reads `Private.*` and gets ours.
--   * The files carrying our fixes (ClassicAPI, C_Item, C_Container, C_Timer, Enum) therefore load
--     ALWAYS and have no SKIP guard.
--   * The remaining files keep the guard. The claim that used to stand here -- "a guarded file
--     publishes nothing TSM reads" -- was measured false for Enum.lua: TSM reads Enum.ItemClass alone
--     98 times, from six files outside this layer, and with the guard in place every one of those was
--     answered by whichever addon happened to own _G.Enum. A neighbour publishing auction-category ids
--     (Weapon=1, Armor=2, no Profession) made every disenchantable item look non-disenchantable, with
--     no error to find. So the rule is: a file whose values TSM's own logic compares against carries a
--     fix by definition and must not be guarded.
--
-- __TSM_ClassicAPI_SKIP therefore still means "the standalone is here", and it is now also readable as
-- a plain question by the files that stay loaded (ClassicAPI.lua uses it to skip a one-time hook the
-- neighbour has already installed).
local Private = {}
_G.__TSM_ClassicAPI_Private = Private

-- Our scan tooltip's frame name. It has to stop being "CAPI_ScanTooltip" now that ClassicAPI.lua loads
-- unconditionally: the standalone creates a frame under that very name, and the second CreateFrame does
-- not fail -- it takes over the global. The line readers address font strings BY NAME
-- (_G[name.."TextLeft"..n], the 3.3.5a idiom, see FrameXML GameTooltip.lua:126), so with one name and
-- two frames one copy would set text on its own tooltip and read it back off the other's. A separate
-- name keeps the two tooltips separate.
Private.TooltipName = "TSMClassicAPIScanTooltip"

_G.__TSM_ClassicAPI_SKIP = (IsAddOnLoaded and IsAddOnLoaded("!!!ClassicAPI")) and true or false

-- Publish our implementation without taking a name away from anyone.
--   nothing there        -> publish ours, `Private[name]` and `_G[name]` are the same table;
--   someone else's table -> theirs stays theirs, we only add the keys it does not have;
--   ours already         -> nothing to do.
-- `Private[name]` is always ours, so TSM's own call sites are unaffected by which case happened.
--
--! WotLK fix: keys starting with `_` are never gap-filled. They are private markers about OUR copy,
--! not API surface, and copying one onto a neighbour's table makes that table lie about itself:
--! `C_Timer._version = 2` landed on Cell's timer engine, whose functions were all Cell's, and the
--! audit harness -- which took that marker as proof of ownership -- graded Cell's engine as ours.
function Private.Publish(Name, Ours)
	Private[Name] = Ours
	local Live = _G[Name]
	if ( Live == nil ) then
		_G[Name] = Ours
	elseif ( Live ~= Ours and type(Live) == "table" and type(Ours) == "table" ) then
		for Key, Value in pairs(Ours) do
			local Marker = type(Key) == "string" and Key:sub(1, 1) == "_"
			if ( Live[Key] == nil and not Marker ) then
				Live[Key] = Value
			end
		end
	end
	return Ours
end
