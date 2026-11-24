local ContentProvider = game:GetService("ContentProvider")
local TweenService = game:GetService("TweenService")
local Scene = require(script.Parent.DivePrisonScene)
local beats = Scene.beats

local IntakeAudio = {}
local assets = {
	ventilation = 9125446543,
	machinery = 9125767459,
	latch = 9118138693,
	gate = 9116831290,
	stop = 9117022316,
	leftBoot = 9114523358,
	rightBoot = 9114523345,
	cloth = 9113824230,
	knees = 9113473249,
	palm = "action_jump_land.mp3",
	click = 9118138693,
	pulse = "action_jump_land.mp3",
}

local cues = {
	{beats.latch, "latch", .58, .72},
	{beats.latch+.12, "gate", .41, 1.36, 1.48},
	{1.38, "leftBoot", .34, .99},
	{1.85, "rightBoot", .37, 1.04},
	{beats.gateStop, "stop", .51, .93},
	{beats.shove, "cloth", .48, 1.22},
	{2.91, "leftBoot", .55, 1.05},
	{3.31, "rightBoot", .47, .92},
	{3.84, "leftBoot", .51, .95},
	{4.26, "rightBoot", .46, 1.03},
	{4.78, "leftBoot", .43, 1.08},
	{5.14, "rightBoot", .45, .88},
	{beats.knees, "knees", .9, .94},
	{beats.hand, "palm", .28, 1.41},
	{6.16, "cloth", .25, .86},
	{7.56, "rightBoot", .17, .92},
	{beats.grip-.10, "rightBoot", .44, .96},
	{beats.grip+.14, "leftBoot", .46, 1.05},
	{beats.grip+.29, "cloth", .52, .95},
	{beats.injector, "click", .46, 1.05},
	{beats.contact, "click", .31, .75},
	{beats.contact+.12, "cloth", .47, 1.11},
	{16.9, "pulse", .53, .47},
	{17.42, "pulse", .47, .44},
	{beats.slump, "pulse", .47, .40},
	{18.37, "cloth", .27, .78},
	{18.94, "pulse", .25, .36},
}

local function uri(asset)
	return if type(asset)=="number" then "rbxassetid://"..asset else "rbxasset://sounds/"..asset
end

function IntakeAudio.preload()
	task.spawn(function()
		local ids = {[Scene.dialogueAsset]=true}
		for _,asset in assets do ids[asset]=true end
		local content = {}
		for asset in ids do
			local sample = Instance.new("Sound")
			sample.SoundId=uri(asset)
			table.insert(content,sample)
		end
		pcall(function() ContentProvider:PreloadAsync(content) end)
		for _,sample in content do sample:Destroy() end
	end)
end

local function createSound(parent,name,asset)
	local sound = Instance.new("Sound")
	sound.Name,sound.SoundId,sound.Volume = name,uri(asset),0
	sound.RollOffMode=Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance,sound.RollOffMaxDistance=5,42
	sound.Parent=parent
	return sound
end

local function equalize(sound,low,mid,high)
	local eq = Instance.new("EqualizerSoundEffect")
	eq.LowGain,eq.MidGain,eq.HighGain=low,mid,high
	eq.Parent=sound
	return eq
end

function IntakeAudio.new(folder,stage)
	local gateSource=Instance.new("Part")
	gateSource.Name="Gate audio position"
	gateSource.Transparency,gateSource.Anchored=1,true
	gateSource.CanCollide,gateSource.CanTouch,gateSource.CanQuery=false,false,false
	gateSource.Position=stage.gate
	gateSource.Parent=folder

	local sounds={}
	local emitters={
		leftBoot=stage.leftGuard, rightBoot=stage.rightGuard,
		latch=gateSource, gate=gateSource, stop=gateSource,
		click=stage.rightGuard,
	}
	for name,asset in assets do sounds[name]=createSound(emitters[name] or folder,name,asset) end
	local room,machinery=sounds.ventilation,sounds.machinery
	room.PlaybackSpeed,machinery.PlaybackSpeed=.90,.83
	room.Looped,machinery.Looped=true,true
	local roomEQ=equalize(room,1,-3,-8)
	local machineryEQ=equalize(machinery,2,-9,-20)
	equalize(sounds.knees,3,-1,-7)
	equalize(sounds.latch,4,0,-7)
	equalize(sounds.pulse,3,-20,-37)
	room:Play()
	machinery:Play()
	local voice=createSound(folder,"General recording",Scene.dialogueAsset)
	voice.Volume=1.06
	local nextCue=1
	local voiceStarted=false
	local speech=0
	local previousTime=0
	return function(t)
		local dt=math.max(0,t-previousTime)
		previousTime=t
		while cues[nextCue] and cues[nextCue][1]<=t do
			local at,key,volume,speed,fade=table.unpack(cues[nextCue])
			nextCue+=1
			local sound=sounds[key]
			if t-at<.35 then
				sound:Stop()
				sound.Volume,sound.PlaybackSpeed,sound.TimePosition=volume,speed,0
				sound:Play()
				if fade then
					task.delay(fade,function()
						if not sound.Parent then return end
						TweenService:Create(sound,TweenInfo.new(.18),{Volume=0}):Play()
					end)
				end
			end
		end
		if not voiceStarted and t>=beats.voice and voice.IsLoaded and t<beats.voice+.8 then
			voiceStarted=true
			voice:Play()
		end
		local fade=math.clamp((t-beats.slump)/1.8,0,1)
		local speaking=math.clamp((t-beats.voice-.67)/.24,0,1)*(1-math.clamp((t-beats.order)/.45,0,1))
		local duck=1-.54*speaking
		local open=math.clamp((t-beats.latch)/4,0,1)
		room.Volume=(.28+.13*open)*duck*(1-fade*.92)
		machinery.Volume=(.2-.075*open)*duck*(1-fade*.8)
		roomEQ.HighGain=-8-28*fade
		machineryEQ.HighGain=-20-12*fade
		local talking=voice.Playing
		local voiceTime=if talking then voice.TimePosition else nil
		local level=if talking then math.clamp((voice.PlaybackLoudness-4)/185,0,1) else 0
		speech+=(level-speech)*(1-math.exp(-dt*(if level>speech then 26 else 15)))
		local subtitleTime=voiceTime or (t-beats.voice)
		return speech,voiceTime,subtitleTime>=.99 and subtitleTime<=3.78
	end
end

function IntakeAudio.wake(folder)
	local engine=createSound(folder,"Kestrel machinery",assets.machinery)
	engine.Looped,engine.PlaybackSpeed=true,.64
	equalize(engine,4,-9,-21)
	local clothes=createSound(folder,"Sleeve on deck",assets.cloth)
	clothes.PlaybackSpeed=.90
	engine:Play()
	local braced=false
	return function(t)
		engine.Volume=.36*math.clamp(t/.66,0,1)*(1-.72*math.clamp((t-2.26)/.44,0,1))
		if not braced and t>.49 then
			braced=true
			clothes.Volume=.39
			clothes:Play()
		end
	end
end

return IntakeAudio
