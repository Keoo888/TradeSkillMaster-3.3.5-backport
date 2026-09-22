--! WotLK fix: no SKIP guard, and no `if ( not C_Timer ) then` wrapper around the body either. Both
--! amounted to the same thing -- "somebody else already has a C_Timer, stand down" -- and with the
--! standalone !!!ClassicAPI addon installed that handed TSM's fourteen C_Timer.After calls to a copy
--! without the fix in New() below. Ours is built unconditionally now and published through
--! Private.Publish: TSM reads Private.C_Timer, the neighbour keeps whatever it installed. See
--! _Prelude.lua for the whole picture.
local Private = __TSM_ClassicAPI_Private

local Type = type
local SetMetaTable = setmetatable

--! WotLK fix: our own frame, unnamed. It used to be `TimerFrame or CreateFrame("Frame", "TimerFrame")`
--! -- with the standalone installed that `or` would ADOPT the neighbour's timer frame and the
--! animation groups created on it would be ours while the frame stayed theirs. Nothing reads the name
--! (grep: the creation site was its only mention in the whole tree), so there is nothing to publish
--! and no reason to claim a global name for it.
local C_Timer = CreateFrame("Frame")
local Registry = SetMetaTable({}, { __mode = "k" }) -- Registry maps the "Public" proxy table to the "Internal" Animation object
local Pool = {}

local function Release(Timer)
	Timer.Proxy = nil
	Timer.Callback = nil
	Timer.Iteration = nil
	Pool[#Pool + 1] = Timer
end

local function Cancel(Proxy)
	local Timer = Registry[Proxy]
	if ( Timer ) then
		Timer:Stop()
		Release(Timer)
		Registry[Proxy] = nil
	end
end

local TimerMethods = { -- Methods attached to timer object.
	Cancel = Cancel,
	IsCancelled = function(Proxy) return Registry[Proxy] == nil end
} TimerMethods.__index = TimerMethods

local function OnFinished(Timer)
	Timer.Callback(Timer.Proxy)

	if ( Timer.Callback ) then
		local Iteration = Timer.Iteration

		if ( Iteration ) then
			if ( Iteration == 1 ) then
				Cancel(Timer.Proxy)
			else
				Timer.Iteration = Iteration - 1
			end
		elseif ( not Timer.Proxy ) then
			Release(Timer)
		end
	end
end

local function New()
	local TimerIndex = #Pool

	if ( TimerIndex > 0 ) then
		local Timer = Pool[TimerIndex]
		Pool[TimerIndex] = nil
		return Timer
	end

	local A = C_Timer:CreateAnimationGroup()
	--! WotLK fix: `Timer` had no `local`, so the cold path of the pool wrote and then read
	--! back a global named `Timer` (Lua 5.1 bytecode: SETGLOBAL Timer on this line,
	--! GETGLOBAL Timer on the next two). Rule 3 -- the addon must not own a foreign global:
	--! any neighbour that leaks the same very common name is silently clobbered here, and we
	--! in turn depend on nobody writing it between the three lines below. The sibling branch
	--! above already spells the local out (`local Timer = Pool[TimerIndex]`), so this was a
	--! forgotten keyword, not a published API.
	local Timer = A:CreateAnimation("Animation")
	Timer:SetScript("OnFinished", OnFinished)
	return Timer
end

local function Create(Duration, Callback, Iteration, Ticker)
	local Timer = New()

	if ( Ticker ) then
		local Proxy = SetMetaTable({}, TimerMethods)
		Registry[Proxy] = Timer
		Timer.Proxy = Proxy
		Timer.Iteration = Iteration
	end

	Timer.Callback = Callback
	Timer:GetParent():SetLooping((Ticker and (not Iteration or Iteration > 1)) and "REPEAT" or "NONE")
	Timer:SetDuration(Duration > 0 and Duration or .01)
	Timer:Play()

	return Timer.Proxy
end

function C_Timer.After(Duration, Callback, _)
	if ( Type(Duration) ~= "number" ) then
		Duration, Callback = Callback, _
	end

	Create(Duration, Callback)
end

function C_Timer.NewTimer(Duration, Callback, _)
	if ( Type(Duration) ~= "number" ) then
		Duration, Callback = Callback, _
	end

	return Create(Duration, Callback, 1, true)
end

function C_Timer.NewTicker(Duration, Callback, Iteration, _)
	if ( Type(Duration) ~= "number" ) then
		Duration, Callback, Iteration = Callback, Iteration, _
	end

	return Create(Duration, Callback, Iteration, true)
end

C_Timer._version = 2

-- Global
Private.Publish("C_Timer", C_Timer)
