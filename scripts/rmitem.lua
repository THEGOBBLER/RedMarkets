function onInit()

end


--checks the notes field for the specificed string.
--qualities supported: hungry, capped, manpower, static
function hasQuality(itemNode, quality)
	quality = string.lower(quality)
	local itemQualities = (string.lower(DB.getValue(itemNode, "qualities"))) --get the entire contents of the qualities box
		if itemQualities:match(quality) == quality then --check for a match
			return true
		else
			return false
		end				
end

function checkItemsForQuality(sheet, quality) --checks entire inventory list for a quality and returns the number of times that quality appears
	local items = sheet.getChild("inventorylist").getChildren()
	local numoccur = 0

	for _,v in pairs(items) do		
		if hasQuality(v, quality) then
			numoccur = numoccur + 1						
		end		
	end

	return numoccur --returns the number of times this quality has occurred in the item list

end


function findLinkedSkill(itemNode)
	local charsheet = itemNode.getParent().getParent()
	local linkedskill = DB.getValue(itemNode, "linkedskill")
	local skilllists = {"skillliststr", "skilllistspd", "skilllistadp", "skilllistcha", "skilllistint"}

	if linkedskill == "" then
		return linkedskill, 0, true --if there's no linked skill listed then exit
	end

	for _,v in ipairs(skilllists) do
		local skills = charsheet.getChild(v).getChildren() --grab all the skills in the skill list
		local listatr = v:match("(%l*)", 10) --create a 3 letter identifier for the attribute to use to find the correct fields
		for k,v in pairs(skills) do --go through the returned 
			if v.getChild("name" .. listatr).getValue() == linkedskill then
				return linkedskill, v.getChild("mod" .. listatr).getValue(), false
			end
		end
	end

	return linkedskill, 0, true --if the skill hasn't been found, return the name, 0 and a string to be handled by BuyARoll.

end

function processItemCombat(itemNode) --checks to see if the item is a weapon, if so will cause a damage output when passed back to be rolled
	local killdam, extrakill = DB.getValue(itemNode, "killdamage"), DB.getValue(itemNode, "extrakill")
	local stundam, extrastun = DB.getValue(itemNode, "stundamage"), DB.getValue(itemNode, "extrastun")
	local combatroll = 1	

	if killdam == 0 and stundam == 0 and extrakill == 0 and extrastun == 0 then --if they're all 0 it's probably not a weapon
		combatroll = 0
	end

	return combatroll, killdam, extrakill, stundam, extrastun



end



function BuyARoll(itemNode, rActor) --handle when player presses to roll on an item.
		--1. handle if the player can actually attempt the roll
		local message = ChatManager.createBaseMessage(rActor) 
		local chargecost = 1
		local chargesource = itemNode.getChild("curcharges")

		if hasQuality(itemNode, "capped") and hasQuality(itemNode, "hungry") then 
			chargecost = 2
		end

		if hasQuality(itemNode, "static") then
			chargecost = 0
		end

		if hasQuality(itemNode, "manpower") then --manpower aka melee weapons use rations to power them
			chargesource = itemNode.getParent().getParent().getChild("rations") --so we need to go to the rations field of the sheet
		end

		if chargesource.getValue() >= chargecost then
			chargesource.setValue(chargesource.getValue() - chargecost)
		else
			message.text = "Not enough charges."
			Comm.deliverChatMessage(message)
			return true --exit with the message if there aren't enough charges
		end

		--if we've gotten this far then the player has enough charges to buy the roll

		local linkedskill, linkedskillmod, skillnotfound = findLinkedSkill(itemNode) --first check if the linkedskill field is referencing a pc skill
		local rRoll = {sType = "sRoll", sDesc = "[ITEM]" .. DB.getValue(itemNode, "name"), aDice = { "d10", "r10"}, nMod = linkedskillmod} --begin populating rRoll
		rRoll.combatroll, rRoll.killdam, rRoll.extrakill, rRoll.stundam, rRoll.extrastun = processItemCombat(itemNode) --filling combat bits

		if skillnotfound == true then --if the linked skill has been found, add its name to the message
			rRoll.sDesc = rRoll.sDesc .. "\n" .. "[SKILL]" .. " none"
		else
			rRoll.sDesc = rRoll.sDesc .. "\n" .. "[SKILL]" .. " " .. linkedskill
		end
	
		ActionsManager.performAction(draginfo, rActor, rRoll);

	end




function PlusOne(itemNode) --function for button spending charges to add a +1 to the roll
		local message = ChatManager.createBaseMessage(rActor) 
		local chargecost = 1
		local chargesource = itemNode.getChild("curcharges")

		if hasQuality(itemNode, "capped") then
			message.text = "Item is capped, can't spend charges for +1."
			Comm.deliverChatMessage(message)
			return true
		end
		
		if hasQuality(itemNode, "hungry") then 
			chargecost = 2
		end

		if hasQuality(itemNode, "manpower") then --manpower aka melee weapons use rations to power them
			chargesource = itemNode.getParent().getParent().getChild("rations") --so we need to go to the rations field of the sheet
		end

		if hasQuality(itemNode, "static") then
			chargecost = 0
		end

		if chargesource.getValue() >= chargecost + 1 then --hungry charged weapons still only need 1 charge to fire
			chargesource.setValue((chargesource.getValue()) - chargecost)
		else
			message.text = "Not enough charges. Either 0 or not enough to buy a roll once +1 added."
			Comm.deliverChatMessage(message)
			return true --exit with the message if there aren't enough charges
		end

		ModifierStack.adjustFreeAdjustment(1) --if we've got here then add +1 to the modifier

end

function refreshItem(nodeItem, nodeTarget)
	local maxchargenum = nodeItem.getChild("maxcharges").getValue()
	local itemname = nodeItem.getChild("name").getValue()
	local curcharges = nodeItem.getChild("curcharges")
	local refresh = nodeTarget.getChild("refreshcurnumber")
	local currefresh = refresh.getValue()
	local message = ChatManager.createBaseMessage(nodeTarget)

	if currefresh < 1 then
		message.text = "Not enough refresh to refresh item."
		Comm.deliverChatMessage(message)
		return true
	else
		refresh.setValue(currefresh - 1)
		curcharges.setValue(maxchargenum)
		message.text = itemname .. " has been refreshed using one refresh."
		Comm.deliverChatMessage(message)
	end



end


--[[Bank and accounting stuff begins, in here because :effort:]]

function handleBountyTransfer(to, from, amount) --function to handle the 'transfer to x' buttons on the charsheet
	local sheet = to.getParent().getParent().getParent()
	local tonum = to.getValue()
	local fromnum = from.getValue()
	local amountnum = amount.getValue()
	local message = ChatManager.createBaseMessage(sheet)

	if fromnum < amountnum then
		message.text = "Not enough bounty to make transfer."
		Comm.deliverChatMessage(message)
		return true
	else
		from.setValue(fromnum - amountnum)
		to.setValue(tonum + amountnum)
		message.text = amountnum .. " bounty transferred."
		Comm.deliverChatMessage(message)
	end
	
end



function refreshAccounting(sheet) --updates fields on accounting sheet
	local sustcost = 2 --sustenance is 2 + dependants
	local items = sheet.getChild("inventorylist").getChildren()
	local maintcost = 0

	--sustenance begins

	for i=1,6 do --there are 6 possible dependants
		if DB.getValue(sheet, "Dependant" .. i) ~= "" and DB.getValue(sheet, "Dependant" .. i) then --if the string isn't blank or nil then there's a dependant
			sustcost = sustcost + 1
		end
	end

	DB.setValue(sheet, "sustenencecost", "number", sustcost)

	--maint begins
	--go through all the items the player has and grab upkeep values from them
	for _,v in pairs(items) do
		if v.getChild("noupkeep").getValue() == 0 then --each inventory item has a button that lets it ignore upkeep		
			local itemupkeep = v.getChild("upkeep").getValue()
			maintcost = maintcost + itemupkeep			
		end
	end

	DB.setValue(sheet, "maintenancecost", "number", maintcost )
	DB.setValue(sheet, "total", "number", DB.getValue(sheet, "maintenancecost") + sustcost)


	return sustcost, maintcost

end

function processSheetMisc(sheet, nogear) --does misc things like setting refresh to ADP etc

end

function processAccounting(sheet) --processes the accounting for sust and maint
	local sustcost, maintcost = refreshAccounting(sheet) --refresh accounting and get up to date costs
	local handbounty = sheet.getChild("coins.slot1.amount")
	local nhandbounty = handbounty.getValue()
	local message = ChatManager.createBaseMessage(sheet)

	--start with sustenence

	if nhandbounty >= sustcost then
		nhandbounty = nhandbounty - sustcost
		message.text = "[SUSTENENCE]: done! " .. sustcost .. " bounty deducted."
	else
		message.text = "[SUSTENENCE]: not enough bounty! Move dependants one step toward Severed or move more money into on hand bounty and process again."
		processSheetMisc(sheet, true)
		Comm.deliverChatMessage(message)
		return false
	end

	--now maintenance

	if nhandbounty >= maintcost then
		nhandbounty = nhandbounty - maintcost
		message.text = message.text .. "\n [MAINTENANCE]: done! " .. maintcost .. " bounty deducted."
	else
		message.text = message.text .. "\n [MAINTENANCE]: not enough bounty! Deduct " .. maintcost .. " bounty from other sources or begin partial upkeep payment/rolls."
		.. "\n You will manually need to account for any gear adjustments to charsheet e.g. reduced haul from carrying LMG"

		processSheetMisc(sheet, true)
		Comm.deliverChatMessage(message)
		handbounty.setValue(nhandbounty)
		return false
	end

	message.text = message.text .. "\n [INCIDENTALS]: need to be manually done."
	
	handbounty.setValue(nhandbounty)
	processSheetMisc(sheet, false)
	Comm.deliverChatMessage(message)

end

function updateCrewSheet()

		for _,v in pairs(DB.getChildren("partysheet.crewmembers")) do --wipe the existing contents if they exist, or create if they don't
		v.delete();
	end

	-- Determine members of party and grab the values we want from their sheets
	local aParty = {};
	for _,v in pairs(DB.getChildren("partysheet.partyinformation")) do
		local sClass, sRecord = DB.getValue(v, "link");
		if sClass == "charsheet" and sRecord then
			local nodePC = DB.findNode(sRecord);
			if nodePC then
				local nSustenencecost, nMaintenancecost = refreshAccounting(nodePC)
				local nTotal = nSustenencecost + nMaintenancecost
				local sName = StringManager.trim(DB.getValue(v, "name", ""));
				table.insert(aParty, { name = sName, node = nodePC, sustenencecost = nSustenencecost, maintenancecost = nMaintenancecost, total = nTotal } );
			end
		end
	end

	-- Populate the database

	for k,v in pairs(aParty) do
		local datanode = DB.createChild("partysheet.crewmembers")
		DB.setValue(datanode, "name", "string", v.name)
		DB.setValue(datanode, "breakpoint", "number", v.sustenencecost)
		DB.setValue(datanode, "maintenance", "number", v.maintenancecost)
		DB.setValue(datanode, "total", "number", v.total)
		DB.setValue(datanode, "profit", "number", 0)
	end

end