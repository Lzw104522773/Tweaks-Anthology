--[[
+---------------------------------------------------------+
| cdtweaks, NWN-ish Woodland Stride class feat for Druids |
+---------------------------------------------------------+
--]]

-- Apply Ability --

EEex_Opcode_AddListsResolvedListener(function(sprite)
	-- Sanity check
	if not EEex_GameObject_IsSprite(sprite) then
		return
	end
	-- internal function that applies the actual feat
	local apply = function()
		-- Mark the creature as 'feat applied'
		sprite:setLocalInt("gtDruidWoodlandStride", 1)
		--
		local effectCodes = {
			{["op"] = 321, ["res"] = "%DRUID_WOODLAND_STRIDE%"}, -- Remove effects by resource
			--
			{["op"] = 403, ["p1"] = 0xE000000, ["res"] = "GTIMMUNE"}, -- screen effects (entangle, web, grease)
			{["op"] = 101, ["p2"] = 154}, -- immunity to effect
			{["op"] = 101, ["p2"] = 157}, -- immunity to effect
			{["op"] = 101, ["p2"] = 158}, -- immunity to effect
			--
			{["op"] = 142, ["p2"] = %feedback_icon%} -- icon
		}
		--
		for _, attributes in ipairs(effectCodes) do
			sprite:applyEffect({
				["effectID"] = attributes["op"] or EEex_Error("opcode number not specified"),
				["effectAmount"] = attributes["p1"] or 0,
				["dwFlags"] = attributes["p2"] or 0,
				["res"] = attributes["res"] or "",
				["durationType"] = 9,
				["m_sourceRes"] = "%DRUID_WOODLAND_STRIDE%",
				["m_sourceType"] = 1,
				["sourceID"] = sprite.m_id,
				["sourceTarget"] = sprite.m_id,
			})
		end
	end
	-- Check creature's class / flags
	local spriteClassStr = GT_Resource_IDSToSymbol["class"][sprite.m_typeAI.m_Class]
	--
	local spriteFlags = sprite.m_baseStats.m_flags
	-- since ``EEex_Opcode_AddListsResolvedListener`` is running after the effect lists have been evaluated, ``m_bonusStats`` has already been added to ``m_derivedStats`` by the engine
	local spriteLevel1 = sprite.m_derivedStats.m_nLevel1
	local spriteLevel2 = sprite.m_derivedStats.m_nLevel2
	-- any lvl 2+ druid (single/multi/(complete)dual)
	local isDruid = spriteClassStr == "DRUID"
	local isFighterDruid = spriteClassStr == "FIGHTER_DRUID" and (EEex_IsBitUnset(spriteFlags, 0x7) or spriteLevel1 > spriteLevel2)
	local druidLevel = spriteClassStr == "DRUID" and spriteLevel1 or spriteLevel2
	--
	local applyAbility = (isDruid or isFighterDruid) and druidLevel >= 2
	--
	if sprite:getLocalInt("gtDruidWoodlandStride") == 0 then
		if applyAbility then
			apply()
		end
	else
		if applyAbility then
			-- do nothing
		else
			-- Mark the creature as 'feat removed'
			sprite:setLocalInt("gtDruidWoodlandStride", 0)
			--
			sprite:applyEffect({
				["effectID"] = 321, -- Remove effects by resource
				["res"] = "%DRUID_WOODLAND_STRIDE%",
				["sourceID"] = sprite.m_id,
				["sourceTarget"] = sprite.m_id,
			})
		end
	end
end)
