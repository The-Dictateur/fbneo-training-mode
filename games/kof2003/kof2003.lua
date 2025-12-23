assert(rb,"Run fbneo-training-mode.lua")

p1maxhealth = 0x71
p2maxhealth = 0x71

p1maxmeter = 0x168
p2maxmeter = 0x168

local p1char_a = 0x107d1a
local p2char_a = 0x107d1b

local p1char = 1
local p2char = 1

-- Variables para medir startup
local startup_frames = 0
local measuring_startup = false
local was_in_hitstun = false
local prev_start = false
local hitstun_frames = 0
local measuring_hitstun = false
local recovery_frames = 0
local measuring_recovery = false

local prev_p2_stun = 0
local stun_before_hit = 0
local stun_logged = false

local prev_p2_guard = 0
local guard_before_hit = 0
local guard_logged = false

local p1health = {0x2FE91D, 0x2FEA1D, 0x2FEB1D}
local p2health = {0x2FED1D, 0x2FEE1D, 0x2FEF1D}

local p1meter = 0x2FE800 -- + 0x4 = stocks
local p2meter = 0x2FEC00

local p1direction = {0x10108F, 0x10138F, 0x10168F}
local p2direction = {0x101B0F, 0x101E0F, 0x10210F}

local p1combocounter = 0x2FE80F
local p2combocounter = 0x2FEC0F

-- Code standby P1
local p1_state_base = 0x1011D7
--local p2_state_base = 0x101C57
local p2_state_base = 0x2FED3F

-- P2Block
local p2block = 0x101bdd

local p2stun = 0x2FED21
local p2Guard = 0x2FED25

translationtable = {
	"left",
	"right",
	"up",
	"down",
	"button1",
	"button2",
	"button3",
	"button4",
	"coin",
	"start",
	"select",
	["Left"] = 1,
	["Right"] = 2,
	["Up"] = 3,
	["Down"] = 4,
	["Button A"] = 5,
	["Button B"] = 6,
	["Button C"] = 7,
	["Button D"] = 8,
	["Coin"] = 9,
	["Start"] = 10,
	["Select"] = 11,
}

gamedefaultconfig = {
	hud = {
		combotextx=138,
		combotexty=40,
		comboenabled=true,
		p1healthx=2,
		p1healthy=24,
		p1healthenabled=true,
		p2healthx=292,
		p2healthy=24,
		p2healthenabled=true,
		p1meterx=109,
		p1metery=208,
		p1meterenabled=true,
		p2meterx=184,
		p2metery=208,
		p2meterenabled=true,
	},
}

function playerOneFacingLeft()
	return rb(p1direction[p1char])==0
end

function playerTwoFacingLeft()
	return rb(p2direction[p2char])==0
end

function playerOneInHitstun()
	return rb(p2combocounter)~=0
end

function playerTwoInHitstun()
	return rb(p1combocounter)~=0
end

function readPlayerOneHealth()
	return rb(p1health[p1char])
end

function writePlayerOneHealth(health)
	wb(p1health[p1char], health-1)
end

function readPlayerTwoHealth()
	return rb(p2health[p2char])
end

function writePlayerTwoHealth(health)
	wb(p2health[p2char], health-1)
end

function readPlayerOneMeter()
	return rb(p1meter) + rb(p1meter+0x4)*0x48
end

function writePlayerOneMeter(meter)
	wb(p1meter+0x4, meter/0x48)
	wb(p1meter, meter%0x48)
end

function readPlayerTwoMeter()
	return rb(p2meter) + rb(p2meter+0x4)*0x48
end

function writePlayerTwoMeter(meter)
	wb(p2meter+0x4, meter/0x48)
	wb(p2meter, meter%0x48)
end

function infiniteTime()
	ww(0x107D62, 0x6000)
end

-- Standby functions TESTING
------------------------------------
function playerOneStanding()
	local state = rb(p1_state_base)
	return state == 0 or state == 5 or state == 4
end

function playerOnePose()
	return rb(p1_state_base)
end

function playerTwoStanding()
	local state = rb(p2_state_base)
	return state == 0 or state == 5 or state == 4
end

function playerTwoPose()
	return rb(p2_state_base)
end

function p2Blockstun()
	local state = rb(p2_state_base)
	return state == 21 or state == 22 or state == 24 or state == 27 or state == 28
end

function p2Blockstunpose()
	return rb(p2block)
end

function playerTwoBlockStand()
	wb(p2_state_base, 2)
end

function playerTwoStun()
	return rb(p2stun)
end

function playerTwoGuard()
	return rb(p2Guard)
end
------------------------------------

function Run() -- runs every frame
	
	infiniteTime()
	p1char = rb(p1char_a)+1
	p2char = rb(p2char_a)+1
	print (playerTwoPose())

	current_stun = playerTwoStun()
	current_guard = playerTwoGuard()
	
	-- Detectar input para iniciar medición (cualquiera de A, B, C, D)
	local inputs = joypad.get()
	local any_button = inputs["P1 Button A"] or inputs["P1 Button B"] or inputs["P1 Button C"] or inputs["P1 Button D"]
	if any_button and not prev_start then
		startStartupMeasurement()
	end
	prev_start = any_button

	-- Detectar entrada en hitstun (hit confirmado)
	if playerTwoInHitstun() and not was_in_hitstun then
		stun_before_hit = playerTwoStun()
		stun_logged = false
		measuring_advantage = true
		p2_hitstun_frames = 0
		p1_recovery_frames = 0
	end

	if p2Blockstun() and not was_in_blockstun then
		guard_before_hit = playerTwoGuard()
		guard_logged = false
		measuring_block_advantage = true
		p2_blockstun_frames = 0
		p1_recovery_frames = 0
	end
	

	if measuring_advantage then
		if playerTwoInHitstun() then
			p2_hitstun_frames = p2_hitstun_frames + 1
		end
		if not playerOneStanding() then
			p1_recovery_frames = p1_recovery_frames + 1
		end
		if not playerTwoInHitstun() and playerOneStanding() then
			local advantage = p2_hitstun_frames - p1_recovery_frames
			print("Frame Advantage: " .. advantage)
			measuring_advantage = false
			pose5_detected = false
			pose50_detected = false
		end
	end

	if measuring_block_advantage then
		if p2Blockstun() then
			p2_blockstun_frames = p2_blockstun_frames + 1
		end

		if not playerOneStanding() then
			p1_recovery_frames = p1_recovery_frames + 1
		end

		local pose = playerTwoPose()
		if pose == 27 or pose == 28 then
			bonus = true
		end
		

		if not p2Blockstun() and playerOneStanding() then
			local advantage = p2_blockstun_frames - p1_recovery_frames
			if bonus then
				advantage = advantage + 1
			end
			print("Block Frame Advantage: " .. advantage)
			bonus = false
			measuring_block_advantage = false
		end
	end
	
	-- Medición de startup
	if measuring_startup then
		startup_frames = startup_frames + 1
		if playerTwoInHitstun() and not was_in_hitstun then
			startup_frames = startup_frames - 4
			print("Startup: " .. startup_frames)
		end
		was_in_hitstun = playerTwoInHitstun()
	end

	-- Calcular daño de stun
	if playerTwoInHitstun() and not stun_logged then
		if current_stun < stun_before_hit then
			local stun_loss = stun_before_hit - current_stun
			print(string.format(
				"Stun Damage: -%d (from %d to %d)",
				stun_loss,
				stun_before_hit,
				current_stun
			))
			stun_logged = true
		end
	end
	-- Calcular daño de guardia
	if p2Blockstunpose() and not guard_logged then
		if current_guard < guard_before_hit then
			local guard_loss = guard_before_hit - current_guard
			print(string.format(
				"Guard Damage: -%d (from %d to %d)",
				guard_loss,
				guard_before_hit,
				current_guard
			))
			guard_logged = true
		end
	end
	was_in_blockstun = p2Blockstun()
end

-- Función para iniciar la medición de startup
function startStartupMeasurement()
	startup_frames = 0
	measuring_startup = true
	was_in_hitstun = playerTwoInHitstun()
end
