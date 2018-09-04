function onInit()
	ActionsManager.registerResultHandler("sRoll", onRoll);
	ActionsManager.registerResultHandler("initroll", onInitRoll)
end

function returnhitlocation(roll)
	local locations = {"right leg", "right leg", "left leg", "left leg", "right arm", "left arm", "torso", "torso", "torso", "head"}
	local hitlocation = locations[roll]
	return hitlocation
end

function CombatRollMessage(blackroll, redroll, combattable)
	local stundamnum, killdamnum = 0,0
	local extrastun, extrakill = combattable.extrastun, combattable.extrakill
	local hitlocation = returnhitlocation(redroll)
	local returnstring = ""
	local blackrollds, blackrolldk = blackroll, blackroll

	Debug.console(combattable)

	if combattable.killdam == 1 and blackroll == redroll then --killdam is whether or not the button to apply kill damage was pressed.
		killdamnum = (blackroll * 2) --double on a crit, success or failure doesn't matter
	elseif combattable.killdam == 1 then
		killdamnum = blackroll	
	end

	if combattable.stundam == 1 and blackroll == redroll then --same as the above except for stun damage
		stundamnum = (blackroll * 2)
	elseif combattable.stundam == 1 then
		stundamnum = blackroll
	end

	--even if no damage type has been selected, we still output whatever was in the input boxes.
	killdamnum, stundamnum = killdamnum + extrakill, stundamnum + extrastun

	if combattable.killdam == 0 then blackrolldk = 0 end
	if combattable.stundam == 0 then blackrollds = 0 end --if any of the damage types haven't been used, then blackroll shouldn't be used in the output
	
	returnstring = "\n[DAMAGE] \nS: " .. stundamnum .. "(" .. blackrollds .. "+" .. extrastun .. ")" .. 
	"\nK: " .. killdamnum .. "(" .. blackrolldk .. "+" .. extrakill .. ")" ..
	"\nto the " .. hitlocation

	return returnstring;
end


function DeepPrint (e)
    -- if e is a table, we should iterate over its elements
    if type(e) == "table" then
        for k,v in pairs(e) do -- for every element in the table
            print(k)
            DeepPrint(v)       -- recursively repeat the same procedure
        end
    else -- if not, we can just print it
        print(e)
    end
end

function onInitRoll(draginfo, rActor, rRoll)
	local rMessage = ActionsManager.createActionMessage(rSource, rRoll)
	local nodeTarget = ActorManager.getCreatureNode(draginfo)
	local nTotal = rRoll.aDice[1].result + rRoll.nMod

	DB.setValue(nodeTarget, "initresult", "number", nTotal)

	Comm.deliverChatMessage(rMessage)
end

function targetProcessing(draginfo) --checks to see if the player is targeting anything, returns the damage values and any redroll mod from NPC
	local token = CombatManager.getTokenFromCT(draginfo.sCTNode)
	local targets = token.getTargets() --returns token ID #s of all targets
	local combatantnodes = CombatManager.getCombatantNodes() --gets all the nodes in the combat tracker
	local combattable = {combatroll = "0", killdam = 0, stundam = 0, extrakill = 0, extrastun = 0} 
	local redrollmod = 0
	Debug.console("targets = ", targets)
	Debug.console("combatantnodes = ", combatantnodes)
	for _,tid in pairs(targets) do --for every ID # on targets table
		Debug.console("in target loop, current target:", tid)
		for _,v in pairs(combatantnodes) do --run through every node on the combat table
			Debug.console("in combatant loop, current combatant", DB.getValue(v, "tokenrefid"))
			local CTID = tonumber(DB.getValue(v, "tokenrefid", ""))
			Debug.console("Advantage Value is:", DB.getValue(v, "advantage", 0))
			if CTID == tid then
				Debug.console("CT and T IDs match")
				combattable.killdam = DB.getValue(v, "npckilldamage", 0)
				combattable.stundam = DB.getValue(v, "npcstundamage", 0)
				combattable.extrakill = DB.getValue(v, "npcextrakill", 0)
				combattable.extrastun = DB.getValue(v, "npcextrastun", 0)
				if combattable.killdam == 1 or combattable.stundam == 1 or combattable.extrastun > 0 or combattable.extrakill > 0 then
					combattable.combatroll = "1"
				end
				if DB.getValue(v, "advantage", 0) > 0 then 
					redrollmod = DB.getValue(v, "advantage") --and if that token has an advantage field that has a number in it, return it as the redroll mod			
				end
				Debug.console("About to return mod and table. Values are:", redrollmod, combattable)
				return redrollmod, combattable
			end 
			
		end
	end
	Debug.console("About to return 0")
	return 0
end

function onRoll(draginfo, rActor, rRoll)
	local combattable = {killdam = tonumber(rRoll.killdam), extrakill = tonumber(rRoll.extrakill), stundam = tonumber(rRoll.stundam), extrastun = tonumber(rRoll.extrastun)}
	local rMessage = ActionsManager.createActionMessage(rSource, rRoll)
	local blackroll = rRoll.aDice[1].result
	local blackrollfinal = blackroll + rRoll.nMod
	local redroll =  rRoll.aDice[2].result
	local redrollmod, combattablereturn = targetProcessing(draginfo)
	local redrollfinal = redroll + redrollmod
	local outcomev = ""
	local margin = blackrollfinal - redrollfinal
	local success = true

	if combattablereturn then --if the NPC target has values for combat stuff then take the NPC's values instead of the player's current ones.
		combattable = combattablereturn
	end
	--remove rations if this was a buy-a-roll with rations
	if rRoll.usesration == "1" then
		local nodeTarget = ActorManager.getCreatureNode(draginfo)
		local currations = DB.getValue(nodeTarget, "rations")

		DB.setValue(nodeTarget, "rations", "number", (currations - 1))
	end

	if blackroll == redroll then
		if (blackroll % 2 == 0) then outcomev = "CRITICAL SUCCESS!"
			else outcomev = "CRITICAL FAILURE!"; success = false;
			end
			elseif blackrollfinal > redrollfinal then
				outcomev = "SUCCESS by " .. margin
			else
				outcomev = "FAILURE by " .. margin
				success = false
			end	
	rMessage.text = rRoll.sDesc .. "\n" .. outcomev .. "\n" ..
	"[BLACK]: " .. blackrollfinal .. "(" .. blackroll .. " + " .. rRoll.nMod .. ")" .. "\n" ..
	"[RED]: " .. redrollfinal .. "(" .. redroll .. " + " .. redrollmod .. ")" 

	if success then rMessage.font = "skillsuccess" else
		rMessage.font = "skillfailure"
	end

	--Basic Combat stuff begins, only done if appropriate NPC targeted, S+ or K+ buttons checked, or if a number has been entered for static stun/kill damage

	if combattable.stundam > 0 or combattable.killdam > 0 or combattable.extrastun > 0 or combattable.extrakill > 0 then 
		rMessage.text = rMessage.text .. CombatRollMessage(blackroll, redroll, combattable)
	end

	Comm.deliverChatMessage(rMessage);
end


