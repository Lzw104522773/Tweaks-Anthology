--[[
+---------------------------------------------------------+
| cdtweaks, NWN-ish Sneak Attack kit feat for Blackguards |
+---------------------------------------------------------+
--]]

-- Apply ability --

EEex_Opcode_AddListsResolvedListener(function(sprite)
	-- sanity check
	if not EEex_GameObject_IsSprite(sprite) then
		return
	end
	-- internal function that applies the actual bonus
	local apply = function()
		-- Mark the creature as 'feat applied'
		sprite:setLocalInt("gtSneakattBlackguard", 1)
		--
		sprite:applyEffect({
			["effectID"] = 321, -- Remove effects by resource
			["res"] = "%BLACKGUARD_SNEAK_ATTACK%",
			["sourceID"] = sprite.m_id,
			["sourceTarget"] = sprite.m_id,
		})
		sprite:applyEffect({
			["effectID"] = 248, -- Melee hit effect
			["res"] = "%BLACKGUARD_SNEAK_ATTACK%B", -- EFF file
			["durationType"] = 9,
			["m_sourceRes"] = "%BLACKGUARD_SNEAK_ATTACK%",
			["sourceID"] = sprite.m_id,
			["sourceTarget"] = sprite.m_id,
		})
		sprite:applyEffect({
			["effectID"] = 249, -- Ranged hit effect
			["res"] = "%BLACKGUARD_SNEAK_ATTACK%B", -- EFF file
			["durationType"] = 9,
			["m_sourceRes"] = "%BLACKGUARD_SNEAK_ATTACK%",
			["sourceID"] = sprite.m_id,
			["sourceTarget"] = sprite.m_id,
		})
	end
	-- Check creature's class / kit / flags
	local spriteFlags = sprite.m_baseStats.m_flags
	local spriteClassStr = GT_Resource_IDSToSymbol["class"][sprite.m_typeAI.m_Class]
	-- since ``EEex_Opcode_AddListsResolvedListener`` is running after the effect lists have been evaluated, ``m_bonusStats`` has already been added to ``m_derivedStats`` by the engine
	local spriteKitStr = EEex_Resource_KitIDSToSymbol(sprite.m_derivedStats.m_nKit)
	-- Grant the feat to Blackguards (must not be fallen)
	local applyAbility = spriteClassStr == "PALADIN" and spriteKitStr == "Blackguard" and EEex_IsBitUnset(spriteFlags, 9)
	--
	if sprite:getLocalInt("gtSneakattBlackguard") == 0 then
		if applyAbility then
			apply()
		end
	else
		if applyAbility then
			-- do nothing
		else
			-- Mark the creature as 'feat removed'
			sprite:setLocalInt("gtSneakattBlackguard", 0)
			--
			sprite:applyEffect({
				["effectID"] = 321, -- Remove effects by resource
				["res"] = "%BLACKGUARD_SNEAK_ATTACK%",
				["sourceID"] = sprite.m_id,
				["sourceTarget"] = sprite.m_id,
			})
		end
	end
end)

-- Core function --

function %BLACKGUARD_SNEAK_ATTACK%(CGameEffect, CGameSprite)
	if CGameEffect.m_effectAmount == 1 then -- check if can perform a sneak attack
		local sourceSprite = EEex_GameObject_Get(CGameEffect.m_sourceId)
		--
		local targetActiveStats = EEex_Sprite_GetActiveStats(CGameSprite)
		-- limit to once per round
		local conditionalString = EEex_Trigger_ParseConditionalString('!GlobalTimerNotExpired("gtSneakattBlackguardTimer","LOCALS")')
		local responseString = EEex_Action_ParseResponseString('SetGlobalTimer("gtSneakattBlackguardTimer","LOCALS",6)')
		--
		if conditionalString:evalConditionalAsAIBase(sourceSprite) then
			-- if the target is incapacitated || the target is in combat with someone else || the blackguard is invisible
			if EEex_BAnd(targetActiveStats.m_generalState, 0x100029) ~= 0 or CGameSprite.m_targetId ~= sourceSprite.m_id or sourceSprite:getLocalInt("gtSpriteIsInvisible") == 1 then
				responseString:executeResponseAsAIBaseInstantly(sourceSprite)
				--
				CGameSprite:applyEffect({
					["effectID"] = 146, -- Cast spell
					["res"] = "%BLACKGUARD_SNEAK_ATTACK%B", -- SPL file
					["dwFlags"] = 1, -- cast instantly / ignore level
					["sourceID"] = CGameEffect.m_sourceId,
					["sourceTarget"] = CGameEffect.m_sourceTarget,
				})
			end
		end
		--
		responseString:free()
		conditionalString:free()
	elseif CGameEffect.m_effectAmount == 2 then -- actual sneak attack
		local sneakatt = GT_Resource_2DA["sneakatt"]
		--
		local sourceSprite = EEex_GameObject_Get(CGameEffect.m_sourceId)
		local sourceActiveStats = EEex_Sprite_GetActiveStats(sourceSprite)
		--
		local equipment = sourceSprite.m_equipment -- CGameSpriteEquipment
		local selectedWeapon = equipment.m_items:get(equipment.m_selectedWeapon) -- CItem
		local selectedWeaponHeader = selectedWeapon.pRes.pHeader -- Item_Header_st
		--
		local isUsableBySingleClassThief = EEex_IsBitUnset(selectedWeaponHeader.notUsableBy, 22)
		--
		local selectedLauncher = sourceSprite:getLauncher(selectedWeapon:getAbility(equipment.m_selectedWeaponAbility)) -- CItem
		--
		if selectedLauncher then
			local pHeader = selectedLauncher.pRes.pHeader -- Item_Header_st
			isUsableBySingleClassThief = EEex_IsBitUnset(pHeader.notUsableBy, 22)
		end
		--
		local selectedWeaponAbility = EEex_Resource_GetItemAbility(selectedWeaponHeader, equipment.m_selectedWeaponAbility) -- Item_ability_st
		--
		if selectedWeaponAbility.type == 1 and sourceSprite.m_leftAttack == 1 then -- if attacking with offhand ...
			local items = sourceSprite.m_equipment.m_items -- Array<CItem*,39>
			local offHand = items:get(9) -- CItem
			--
			if offHand then
				local pHeader = offHand.pRes.pHeader -- Item_Header_st
				--
				if EEex_Resource_ItemCategoryIDSToSymbol(pHeader.itemType) ~= "SHIELD" then -- if not shield, then overwrite item ability / usability check...
					selectedWeaponAbility = EEex_Resource_GetItemAbility(pHeader, 0) -- Item_ability_st
					isUsableBySingleClassThief = EEex_IsBitUnset(pHeader.notUsableBy, 22)
				end
			end
		end
		--
		local immunityToDamage = EEex_Trigger_ParseConditionalString("EEex_IsImmuneToOpcode(Myself,12)")
		--
		local targetActiveStats = EEex_Sprite_GetActiveStats(CGameSprite)
		--
		local op12DamageType, ACModifier = GT_Utility_DamageTypeConverter(selectedWeaponAbility.damageType, targetActiveStats)
		--
		if not immunityToDamage:evalConditionalAsAIBase(CGameSprite) then
			EEex_GameObject_ApplyEffect(CGameSprite,
			{
				["effectID"] = 0xC, -- Damage
				["dwFlags"] = op12DamageType * 0x10000, -- mode: normal
				["numDice"] = tonumber(sneakatt["STALKER"][string.format("%s", sourceActiveStats.m_nLevel1)]),
				["diceSize"] = 6,
				["m_sourceRes"] = CGameEffect.m_sourceRes:get(),
				["m_sourceType"] = CGameEffect.m_sourceType,
				["sourceID"] = CGameEffect.m_sourceId,
				["sourceTarget"] = CGameEffect.m_sourceTarget,
			})
		else
			EEex_GameObject_ApplyEffect(CGameSprite,
			{
				["effectID"] = 324, -- Immunity to resource and message
				["res"] = CGameEffect.m_sourceRes:get(),
				["m_sourceRes"] = CGameEffect.m_sourceRes:get(),
				["m_sourceType"] = CGameEffect.m_sourceType,
				["sourceID"] = CGameEffect.m_sourceId,
				["sourceTarget"] = CGameEffect.m_sourceTarget,
			})
		end
		--
		immunityToDamage:free()
	end
end
