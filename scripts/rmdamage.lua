--[[
DAMAGE FLOW.

SOURCE: dragged roll
1. onDrop: Roll is dropped onto a token.

2. parseDesc: Roll description is parsed. Parse returns rolltable with: blackroll, redroll, stundam, killdam, extrastun, extrakill, hitloc, hitloclong, result,
crit. 
Parse also handles damage if combatroll has not been specified, and will handle any flip/crit/explosive buttons if implemented.

3. CheckArmour. Checks to see if location is covered by armour. If so, will pass to player sheet (4). If not, will apply direct damage.(5)

4. DamageToIncoming. Passes damage to player sheet for player to optionally reduce by spending armour charges. Once done, will goto:

5. Applies direct damage



rolltable.blackroll = desc:match("%[BLACK%]: %d*%((%d*)") --get the unmodified black dice roll
	rolltable.redroll = desc:match("%[RED%]: (%d*)") --same for redroll	
	rolltable.stundam, rolltable.extrastun = desc:match("S: (%-?%d*)%(%d*%+(%-?%d*)%)") --grab stun damage and extra stun
	rolltable.killdam, rolltable.extrakill = desc:match("K: (%-?%d*)%(%d*%+(%-?%d*)%)") --same for kill
 	rolltable.hitloc = desc:match("to the (.*)") --the hit location is always last with nothing after so it's fine to grab all the characters







]]

OOB_MSGTYPE_CHECKARMOUR = "checkarmour"
OOB_MSGTYPE_APPLYDAMAGE = "applydamage"

function onInit()
	OOBManager.registerOOBMsgHandler(OOB_MSGTYPE_CHECKARMOUR, CheckArmour)
	OOBManager.registerOOBMsgHandler(OOB_MSGTYPE_APPLYDAMAGE, ApplyDamage)
end

function NotifyCheckArmour(rActor, rolltable)

	local msgOOB = {}
	
	msgOOB = rolltable
	msgOOB.sTargetType, msgOOB.snodeTarget = ActorManager.getTypeAndNodeName(rActor)
	msgOOB.type = OOB_MSGTYPE_CHECKARMOUR

	Comm.deliverOOBMessage(msgOOB, "") --hello i am oob message i only deliver a shitty table full of strings hrurhufhfurhrufhufhgughh

end

function NotifyApplyDamage(sTargetType, nodeTarget, hitloc, stundamage, killdamage, silent)

	local msgOOB = {}
	
	msgOOB.hitloc, msgOOB.stundamage, msgOOB.killdamage, msgOOB.silent = hitloc, stundamage, killdamage, silent
	msgOOB.sTargetType, msgOOB.snodeTarget = ActorManager.getTypeAndNodeName(nodeTarget)
	msgOOB.type = OOB_MSGTYPE_APPLYDAMAGE

	Comm.deliverOOBMessage(msgOOB, "") --hello i am oob message i only deliver a shitty table full of strings hrurhufhfurhrufhufhgughh

end


function PlusMinus(sheet, location, amount) --sheet= database node of window, location = name of button that called function, amount = damage to be added
	location = sheet.getChild(location:sub(1,6)) --take the first 6 characters of button name to get the location and type of damage e.g. hdkill	

	if amount == -99 then --99 is sent from the heal all button
		location.setValue(0) 
		else 
		location.setValue(location.getValue() +  amount)
	end
end

function RollToLoc(roll) --takes a natural red roll and converts it to the long and short location forms, returns both as strings
	local locfieldarray = {"rl", "rl", "ll", "ll", "ra", "la", "to", "to", "to", "hd"};
	local roll = tonumber(roll)
	local hitloc = locfieldarray[roll]
	return hitloc
end

function LocToLong(loc) --takes a 2 letter location and turns it to readable long form
	local longloctable = {rl = "right leg", ll = "left leg", ra = "right arm", la = "left arm", to = "torso", hd = "head" }

	for k,v in pairs(longloctable) do
		if k == loc then 
			return v
		end
	end

	return "something fucked up in LocToLong"

end

function DamageToIncoming(sTargetType, nodeTarget, rolltable, explosive) --passes the damage from the hit onto the sheet
	local dMessage = ChatManager.createBaseMessage(nodeTarget)
	local sinctext, kinctext = rolltable.hitloc .. "stuninc", rolltable.hitloc .. "killinc" --incoming damage boxes naming scheme "hdkillinc" for incoming head etc
	
	DB.setValue(nodeTarget, kinctext, "number", rolltable.killdam) --set the value to whatever the incoming damage is
	DB.setValue(nodeTarget, sinctext, "number", rolltable.stundam)
	
	if not explosive then
	dMessage.text = ActorManager.getDisplayName(nodeTarget) .. " has taken " .. rolltable.killdam .. " kill and " .. rolltable.stundam ..
	" stun damage to their armoured " .. rolltable.hitloclong .. "." .. "\n Damage transferred to sheet for reduction by armour."

	Comm.deliverChatMessage(dMessage)
	else
		return true
	end


end

function CheckArmour(rolltable) --actually a msgOOB
	local nodeTarget = DB.findNode(rolltable.snodeTarget)
	local sTargetType = rolltable.sTargetType
	local message = ChatManager.createBaseMessage(nodeTarget)
	local ismob = DB.getValue(nodeTarget, "typemob")
	if sTargetType == "ct" then sTargetType = ActorManager.getType(ActorManager.getActorFromCT(nodeTarget)) end

	--NPC Handling.

	if sTargetType == "npc" then
		local locations = {"hd", "to", "la", "ra", "ll", "rl"} 				 --all possible hitlocs
		if ModifierStack.getModifierKey("button_desktop_explosive") then
			for i=1,6 do
				if DB.getValue(nodeTarget, locations[i] .. "armour") > 0 then --NPC armour is saved as "toarmour", "hdarmour" etc
					DB.setValue(nodeTarget, locations[i] .. "armour", "number", DB.getValue(nodeTarget, locations[i] .. "armour") - 1)
					if ismob == false then message.text = message.text .. LocToLong(locations[i]) .. ": protected by armour. \n" end
				else
					NotifyApplyDamage(sTargetType, nodeTarget, locations[i], rolltable.stundam, rolltable.killdam, true)
					if ismob == false then message.text = message.text .. LocToLong(locations[i]) .. "took damage. \n" end
				end
			end
				Comm.deliverChatMessage(message)
		else
				if DB.getValue(nodeTarget, rolltable.hitloc .. "armour") > 0 then
					DB.setValue(nodeTarget, rolltable.hitloc .. "armour", "number", DB.getValue(nodeTarget, rolltable.hitloc .. "armour") - 1)
					message.text = LocToLong(rolltable.hitloc) .. ": protected by armour. \n"
					Comm.deliverChatMessage(message)					
				else
					NotifyApplyDamage(sTargetType, nodeTarget, rolltable.hitloc, rolltable.stundam, rolltable.killdam)
				end
		end
		return true --if it's an NPC we don't need to do the rest so we exit the function
	end


	if ModifierStack.getModifierKey("button_desktop_explosive") then
		for i=1,6 do
			local locations = {"hd", "to", "la", "ra", "ll", "rl"}
			rolltable.hitloc = locations[i]
			DamageToIncoming(sTargetType, nodeTarget, rolltable, true)
			message.text = rolltable.stundam .. " stun and " .. rolltable.killdam .. " kill explosive damage applied to sheet. Prepare for spam when it is applied!"
			ModifierStack.setModifierKey("button_desktop_explosive", 0, 0) 
			if i == 1 then Comm.deliverChatMessage(message) end
		end
	else
		for i=1,5 do
			if DB.getValue(nodeTarget, "Armour" .. i .. rolltable.hitloc) == 1 then --goes through passed hitloc on armours 1-5 checking if a box is checked
				DamageToIncoming(sTargetType, nodeTarget, rolltable) --if it is checked, armour covers the location. pass the damage to the sheet
				return true
			end	
		end

		NotifyApplyDamage(sTargetType, nodeTarget, rolltable.hitloc, rolltable.stundam, rolltable.killdam) --if single loc damage not applied to sheet then it needs to be real damage
	
	end

end

function HandleHealthIcon(nodeTarget, name, damage) --function to change the colour of the health icon, activated onvaluechanged from the damage boxes

	local cyclerstring = name .. "status" --name of damage box will be something like "hdkill", so we just need to add "status" to get the name of the cycler we want
	local cycler = nodeTarget.getChild(cyclerstring)
	local icon = ""
	local maxdamage = 10
	local percentage = 0

	if name:match("to%l*") then maxdamage = 20 end --torsos have 20 damage boxes
	percentage = (damage / maxdamage) * 100 --calculate the % of the box that is filled with damage

	--compare the damage to the total health, assigning a total health % icon based on the result.
	if percentage == 0 then icon = "icon_health_100"
		elseif percentage > 0 and percentage < 20 then icon = "icon_health_90"
		elseif percentage >= 20 and percentage < 40 then icon = "icon_health_80"
		elseif percentage >= 40 and percentage < 60 then icon = "icon_health_60"
		elseif percentage >= 60 and percentage < 80 then icon = "icon_health_40"
		elseif percentage >= 80 and percentage < 100 then icon = "icon_health_20"
		elseif percentage == 100 then icon = "icon_health_0"
	end

	cycler.setValue(icon) --sets the value of the cycler to the correct icon

end

function HandleEffect(nodeTarget, hitloc) --handles effects for player hit locations

	local hitlocstun = DB.getValue(nodeTarget, hitloc .. "stun")
	local hitlockill = DB.getValue(nodeTarget, hitloc .. "kill")
	local hitlocthreshold = 10 --normal places have 10 hitboxes
	local stuneffectfield = nodeTarget.getChild(hitloc .. "stuneffect") --each iconcycler is called something like "hdstuneffect/hdkilleffect"
	local killeffectfield = nodeTarget.getChild(hitloc .. "killeffect")
	local stuneffect, killeffect = "", ""

	--go through the 2 letter hit location to find out which body part it is referring to: each has its own type of effects.
	if hitloc:match("%la%l*") then
		stuneffect = "icon_winged"
		killeffect = "icon_maimed"
	elseif hitloc:match("%ll%l*") then
		stuneffect = "icon_hobbled"
		killeffect = "icon_lamed"
	elseif hitloc:match("hd%l*") then
		stuneffect = "icon_gassed"
		killeffect = "icon_dead"
	elseif hitloc:match("to%l*") then
		stuneffect = "icon_unconscious"
		killeffect = "icon_dead"
		hitlocthreshold = 20 --torsos have 20 hit boxes
	end

	--this will not remove any current effects on the body part
	if hitlockill >= hitlocthreshold then --effects are triggered on hit locations being full of stun or kill damage
		stuneffectfield.setValue(stuneffect) --sets the value of the iconcycler to the icon we want, might as well do both for full kill
		killeffectfield.setValue(killeffect)
	elseif (hitlocstun + hitlockill) >= hitlocthreshold then --if not full of kill, check stun+kill
		stuneffectfield.setValue(stuneffect)
	else
		return true
	end
end

function NPCAssessDamage(nodeTarget, hitloc) --checks to see if an NPC should be slain or not
	local message = ChatManager.createBaseMessage(nodeTarget)
	local npctype = "typeparttime"
	local locations = {"hd", "to", "la", "ra", "ll", "rl"}
	local mobsize = DB.getValue(nodeTarget, "mobsize")
	local pthp = DB.getValue(nodeTarget, "pthp")

		for i=1,5 do
			local typetable = {"typeparttime", "typefulltime", "typemanagement", "typevector", "typemob"} --cycle through types and determine which type this npc is
			if DB.getValue(nodeTarget, typetable[i]) == 1 then
				npctype = typetable[i]
				break
			end
		end

		--go through the different NPC types and check if they should be dead
		if npctype == "typeparttime" then --part time is dead if it has taken 10 total damage of any type across all locations
			local damagecount = 0
			for i=1,6 do
				damagecount = damagecount + DB.getValue(nodeTarget, locations[i] .. "stun")
				damagecount = damagecount + DB.getValue(nodeTarget, locations[i] .. "kill")
				if damagecount >= pthp then --if the damage threshold has been reached, call the NPC as dead. Otherwise check for more damage.
					message.text = "is down."
					Comm.deliverChatMessage(message)
					return true
				end
			end
		elseif npctype == "typefulltime" then --full time NPCs die if one hit loc is filled with a combination of 10 stun/kill.
			local stundam = DB.getValue(nodeTarget, hitloc .. "stun")
			local killdam = DB.getValue(nodeTarget, hitloc .. "kill")
			if killdam + stundam >= 10 then
				message.text = "is down."
				Comm.deliverChatMessage(message)
			end
		elseif npctype == "typemanagement" or npctype == "typevector" then --for now they are handled the same
			if hitloc == "hd" then
				local stundam = DB.getValue(nodeTarget, hitloc .. "stun")
				local killdam = DB.getValue(nodeTarget, hitloc .. "kill")
				if killdam + stundam >= 10 then
					message.text = "is down."
					Comm.deliverChatMessage(message)
				end
			end
			elseif hitloc == "to" then
				local stundam = DB.getValue(nodeTarget, hitloc .. "stun")
				local killdam = DB.getValue(nodeTarget, hitloc .. "kill")
				if killdam + stundam >= 20 then
					message.text = "is down."
					Comm.deliverChatMessage(message)
				end
			elseif npctype == "typemob" and mobsize <= 0 then
				message.text = "has no zombies left."
				Comm.deliverChatMessage(message)
		end
end

function ApplyDamage(sTargetType, nodeTarget, hitloc, stundamage, killdamage, silent)

	if type(sTargetType) == "table" then --if the first thing passed is a table then it's from msgOOB so we can decode it here because I cba changing the rest of my code
		hitloc = sTargetType.hitloc
		nodeTarget = DB.findNode(sTargetType.snodeTarget)
		stundamage = tonumber(sTargetType.stundamage)
		killdamage = tonumber(sTargetType.killdamage)

		local lol = sTargetType.sTargetType
		sTargetType = lol
	end
	if sTargetType == "ct" then sTargetType = ActorManager.getType(ActorManager.getActorFromCT(nodeTarget)) end --find what type of thing a thing is if the thing is from the CT

	local hitloc = hitloc:lower()
	local fieldstun, fieldkill = hitloc .. "stun", hitloc .. "kill" --convert to name of damage fields on sheet
	local currentstun, currentkill = DB.getValue(nodeTarget, fieldstun), DB.getValue(nodeTarget, fieldkill) --current damage values in the box
	local stunoverflow, killoverflow = 0,0 --overflow values, more important for stun
	local dMessage = ChatManager.createBaseMessage(nodeTarget)
	local maxboxes = 10--normal boxes for each hit location
	local hitloclong = LocToLong(hitloc)
	if fieldstun == "tostun" then local maxboxes = 20 end --torsos have 20 boxes
	local availablestun = (maxboxes - currentstun - currentkill) --essentially blank boxes
	local availablekill = (maxboxes - currentkill) --stun boxes

	if DB.getValue(nodeTarget, "typefulltime") == 1 then maxboxes = 10 end --fulltime enemies have 10 in all boxes

	--mob handling
	if sTargetType == "npc" and DB.getValue(nodeTarget, "typemob") == 1 then
		DB.setValue(nodeTarget, "mobsize", "number", DB.getValue(nodeTarget, "mobsize") - 1)
		dMessage.text = "has been reduced in size by 1."
		if not silent then
			Comm.deliverChatMessage(dMessage)
		end
		NPCAssessDamage(nodeTarget)
		return true
	end



	if availablestun >= stundamage then 
		--if there's more available stun than incoming stun then we can just add it on
		DB.setValue(nodeTarget, fieldstun, "number", (currentstun + stundamage) )
	else
		--otherwise we need to apply what we can and then send the rest to overflow to be applied as kill
		DB.setValue(nodeTarget, fieldstun, "number", (currentstun + availablestun) )
		stunoverflow = stundamage - availablestun
	end

	--kill damage handling

	if availablekill > (stunoverflow + killdamage) then
		--if the kill damage to be will keep kill below 10 then we apply it and set overflow to 0
		DB.setValue(nodeTarget, fieldkill, "number", (stunoverflow + killdamage + currentkill))
	else
		--otherwise we set to 10 and calculate overflow
		DB.setValue(nodeTarget, fieldkill, "number", 10)
		killoverflow = (currentkill + killoverflow) - maxboxes
	end

	--tidy up. First refresh current values
	currentstun, currentkill = DB.getValue(nodeTarget, fieldstun), DB.getValue(nodeTarget, fieldkill)
	if currentstun + currentkill > maxboxes then
		--remove excess stun damage so stun + kill == maxboxes
		DB.setValue(nodeTarget, fieldstun, "number", (maxboxes - currentkill))
	end

	--setup the message
	dMessage.text = ActorManager.getDisplayName(nodeTarget) .. " has taken damage to the " .. hitloclong .. "\n[STUN]: " .. stundamage .. " (" .. stunoverflow .. " overflow)" ..
	"\n[KILL:] " .. (killdamage+stunoverflow) .. " (" .. killoverflow .. " overflow with no effect)" ..
	"\nLocation now has " .. DB.getValue(nodeTarget, fieldstun) .. " stun damage and " .. DB.getValue(nodeTarget, fieldkill) .. " kill damage."

	if not silent then
		Comm.deliverChatMessage(dMessage)
	end

	--run check for effects
	if sTargetType == "npc" then
		NPCAssessDamage(nodeTarget, hitloc)
	else
		HandleEffect(nodeTarget, hitloc)
	end

end


 --couldn't figure out the method for transferring customdata via roll so it could be read onDrag, so we get to mine the roll description for info yay pattern matching
 --if players get funny with putting nonsense into their skill roll fields like then this will fail since I don't bother to sanitise the input
function parseDesc(desc, rActor)
	local rolltable = {}

	rolltable.blackroll = desc:match("%[BLACK%]: %d*%((%d*)") --get the unmodified black dice roll
	rolltable.redroll = desc:match("%[RED%]: (%d*)") --same for redroll	
	rolltable.stundam, rolltable.extrastun = desc:match("S: (%-?%d*)%(%d*%+(%-?%d*)%)") --grab stun damage and extra stun
	rolltable.killdam, rolltable.extrakill = desc:match("K: (%-?%d*)%(%d*%+(%-?%d*)%)") --same for kill
	local stunraw, killraw = false, false
	--hitlocs are defined after handling for swapped roles. At the bottom of the function.
 	message = ChatManager.createBaseMessage(rActor)

 

	if desc:match("CRITICAL FAILURE") ~= nil then
		rolltable.crit = true
		rolltable.result = "Failure"
	elseif
		desc:match("CRITICAL SUCCESS") ~= nil then
		rolltable.crit = true
		rolltable.result = "Success"
	elseif
		desc:match("SUCCESS by %d*") ~= nil then
		rolltable.crit = false
		rolltable.result = "Success"
	elseif
		desc:match("FAILURE by %-?%d*") ~= nil then
		rolltable.crit = false
		rolltable.result = "Failure"
	else
	end
		--begin handling for the roll not being a combatroll/player forgetting to click the button.
		if rolltable.stundam == nil then --stundam since it's first. the combatroll message output will always return at least 0
			rolltable.killdam = rolltable.blackroll --assume blackroll in kill, as per a casualty bite
			rolltable.stundam = 0 --stundam set to 0
			killraw = true 
		end

	--see what damage types were selected
	if tonumber(rolltable.stundam) > 0 then
 		stunraw = true
 	end
 	if tonumber(rolltable.killdam) > 0 then
 		killraw = true
 	end

--handling for the desktop buttons

--swap handling.
if ModifierStack.getModifierKey("button_desktop_swap") then
	local oldblack = rolltable.blackroll
	local oldred = rolltable.redroll
	rolltable.blackroll = oldred
	rolltable.redroll = oldblack
	if killraw then rolltable.killdam = rolltable.blackroll + rolltable.extrakill end
	if stunraw then rolltable.stundam = rolltable.redroll + rolltable.extrastun end
	message.text = "Black and red will be swapped for damage application."
	Comm.deliverChatMessage(message)
	ModifierStack.setModifierKey("button_desktop_swap", 0, 0) --idk wtf this does but it seems to stop the swap being cancelled if the button is still clicked after the first one.
end

--upgrade/downgrade handling
if ModifierStack.getModifierKey("button_desktop_upgrade") and rolltable.crit == false then --can't upgrade something if it's already a crit
	rolltable.crit = true
	if killraw then rolltable.killdam = rolltable.killdam + rolltable.blackroll end
	if stunraw then rolltable.stundam = rolltable.stundam + rolltable.blackroll end
	message.text = "Roll upgraded to crit from non crit, black die damage will be doubled."
	Comm.deliverChatMessage(message)
	ModifierStack.setModifierKey("button_desktop_upgrade", 0, 0) 
elseif ModifierStack.getModifierKey("button_desktop_downgrade") and rolltable.crit == true then
	rolltable.crit = false
	if killraw then rolltable.killdam = rolltable.killdam - rolltable.blackroll end
	if stunraw then rolltable.stundam = rolltable.stundam - rolltable.blackroll end
	message.text = "Roll downgraded from crit to non crit, black die damage will be halved."
	Comm.deliverChatMessage(message)
	ModifierStack.setModifierKey("button_desktop_downgrade", 0, 0) 
end

 	rolltable.hitloc = RollToLoc(rolltable.redroll)
 	rolltable.hitloclong = LocToLong(rolltable.hitloc)





return rolltable --return all the info as a table to be used by whatever function
end

function onDrop(nodetype, rActor, draginfo)

	NotifyCheckArmour(rActor, parseDesc(draginfo.getDescription(), rActor))

end

function ApplyDamageButton(nodeTarget, sTargetType)
	local incominglocs = {"hdstuninc", "hdkillinc", "tostuninc", "tokillinc", "lastuninc", "lakillinc", "llstuninc", "llkillinc", "rastuninc", 
	"rakillinc", "rlstuninc", "rlkillinc"}
	local currentlocs = {"hdstun", "hdkill", "tostun", "tokill", "lastun", "lakill", "llstun", "llkill", "rastun", 
	"rakill", "rlstun", "rlkill"}

	for k,v in pairs(incominglocs) do --go through incoming damage locations
		vs = tostring(v) --has a hissy fit if I just use k or v. vs = current incoming hit location e.g. "lakillinc"
		cvs = tostring(currentlocs[k]) --has a hissy fit if I just use k or v. cvs = current damage location e.g. "lakill"
		hitloc = cvs:match("(%l%l)")

		if DB.getValue(nodeTarget, vs) > 0 then --if any incomingloc is greater than zero
			
			if vs:match("%l%lstun%l+") then --if it's stun damage then
				RMDamage.ApplyDamage(sTargetType, nodeTarget, hitloc, DB.getValue(nodeTarget, vs), 0) --apply as stun
			else
				RMDamage.ApplyDamage(sTargetType, nodeTarget, hitloc, 0, DB.getValue(nodeTarget, vs)) --otherwise apply as kill. a bit spammy but fukit
			end

			DB.setValue(nodeTarget, vs, "number", 0) --set incoming to 0
		end
	end
end

function KillToStun(nodeTarget, hitloc)
	local message = ChatManager.createBaseMessage(nodeTarget)
	local name = ActorManager.getDisplayName(nodeTarget)
	
	for i=1,5 do	
		if DB.getValue(nodeTarget, "Armour" .. i .. hitloc) == 1 then --goes through passed hitloc on armours 1-5 checking if a box is checked
			local armourname = "Armour" .. i
			local armourcharges = DB.getValue(nodeTarget, armourname .. "CurCharge")
			local armourstring = DB.getValue(nodeTarget, armourname)
			local killinc = DB.getValue(nodeTarget, hitloc .. "killinc")
			local stuninccur = DB.getValue(nodeTarget, hitloc .. "stuninc")
			local newstuninc = killinc + stuninccur

			if armourcharges == 0 then
				message.text = name .. ": not enough charges in " .. armourstring
				Comm.deliverChatMessage(message)
				return true
			end

			if killinc > 0 then
				DB.setValue(nodeTarget, hitloc .. "stuninc", "number", newstuninc)
				DB.setValue(nodeTarget, hitloc .. "killinc", "number", 0)
				DB.setValue(nodeTarget, armourname .. "CurCharge", "number", armourcharges - 1)
				message.text = name .. ": all kill damage for " .. LocToLong(hitloc) .. " converted to stun. New incoming stun damage is " .. newstuninc .. " (was " .. stuninccur .. "). One charge used."
				Comm.deliverChatMessage(message)
				return true
			else
				message.text = name .. ": no incoming kill damage to convert for " .. armourstring .. "."
				Comm.deliverChatMessage(message)
				return true
			end
		end	

	end
	message.text = name .. "has no armour for location " .. LocToLong(hitloc)
	Comm.deliverChatMessage(message)
end

function MinusOneStun(nodeTarget, hitloc)
	local message = ChatManager.createBaseMessage(nodeTarget)
	local name = ActorManager.getDisplayName(nodeTarget)
	
	for i=1,5 do	
		if DB.getValue(nodeTarget, "Armour" .. i .. hitloc) == 1 then --goes through passed hitloc on armours 1-5 checking if a box is checked
			local armourname = "Armour" .. i
			local armourcharges = DB.getValue(nodeTarget, armourname .. "CurCharge")
			local armourstring = DB.getValue(nodeTarget, armourname)
			local stuninccur = DB.getValue(nodeTarget, hitloc .. "stuninc")
			local newstuninc = stuninccur - 1

			if armourcharges == 0 then
				message.text =  name .. ": not enough charges in " .. armourstring
				Comm.deliverChatMessage(message)
				return true
			end

			if stuninccur > 0 then
				DB.setValue(nodeTarget, hitloc .. "stuninc", "number", newstuninc)
				DB.setValue(nodeTarget, armourname .. "CurCharge", "number", armourcharges - 1)
				message.text = name .. ": -1 incoming stun for " .. LocToLong(hitloc) .. " New incoming stun damage is " .. newstuninc .. " One charge used."
				Comm.deliverChatMessage(message)
				return true
			else
				message.text = name ..  ": no incoming stun damage to alter for " .. armourstring .. "."
				Comm.deliverChatMessage(message)
				return true
			end
		end	

	end
	message.text = name .. "has no armour for this location"
	Comm.deliverChatMessage(message)
end

