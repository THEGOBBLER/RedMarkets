-- Copyright SmiteWorks USA, LLC., 2011

local sCharEntryClass = "characterlist_entry"
local tCharEntryDecorators = {}
local tCharEntries = {};

local tDropHandlers = {};

function onInit()
	if User.isHost() then
		registerDropHandler("number", onNumberDrop)
	end
	registerDropHandler("string", onStringDrop)
	registerDropHandler("portraitselection", onPortraitDrop)
	registerDropHandler("shortcut", onShortcutDrop)
	if User.isHost() then
		registerDropHandler("", onDefaultDrop);
	end
end

--
-- Character list management
--

function addDecorator(sName, fDecorator)
	tCharEntryDecorators[sName] = fDecorator
end

function removeDecorator(sName)
	tCharEntryDecorators[sName] = nil
end

function setEntryClass(sWindowClass)
	sCharEntryClass = sWindowClass
end

function createEntry(ctrlCharList, sIdentity)
	-- Create control and add basic items
	local ctrlChar = ctrlCharList.createControl(sCharEntryClass, "ctrl_" .. sIdentity)
	ctrlChar.createWidgets(sIdentity)
	ctrlChar.setMenuItems(sIdentity);

	-- Track entries
	tCharEntries[sIdentity] = ctrlChar;
	
	-- Call decorators
	for _,fDecorator in pairs(tCharEntryDecorators) do
		fDecorator(ctrlChar, sIdentity)
	end
end

function destroyEntry(ctrlChar, sIdentity)
	-- Destory control
	ctrlChar.destroy();
	
	-- Track entries
	tCharEntries[sIdentity] = nil;
end

function getEntry(sIdentity)
	return tCharEntries[sIdentity];
end

--
-- Drop handling
--

function registerDropHandler(sDropType, fHandler)
	tDropHandlers[sDropType] = fHandler;
end

function unregisterDropHandler(sDropType)
	tDropHandlers[sDropType] = nil;
end

function processDrop(sIdentity, draginfo)
	-- CHECK REGISTERED DROP HANDLERS
	local sDropType = draginfo.getType();
	
	for sKey, fHandler in pairs(tDropHandlers) do
		if sKey == sDropType then
			return fHandler(sIdentity, draginfo);
		end
	end

	if tDropHandlers[""] then
		return tDropHandlers[""](sIdentity, draginfo);
	end
	
	-- NO DROP HANDLER FOUND
	return nil;
end

--
-- Default drop handlers
--

function onNumberDrop(sIdentity, draginfo)
	local msg = {};
	msg.text = draginfo.getDescription();
	msg.font = "systemfont";
	msg.icon = "";
	msg.dice = {};
	msg.diemodifier = draginfo.getNumberData();
	msg.dicesecret = false;
	
	Comm.deliverChatMessage(msg);
	return true
end

function onStringDrop(sIdentity, draginfo)
	ChatManager.processWhisperHelper(User.getIdentityLabel(sIdentity), draginfo.getStringData());
	return true;
end

function onPortraitDrop(sIdentity, draginfo)
	if User.isHost() or User.isOwnedIdentity(sIdentity) then
		User.setPortrait(sIdentity, draginfo.getStringData());
		return true;
	end
end

function onShortcutDrop(sIdentity, draginfo)
	local sClass, sRecord = draginfo.getShortcutData();
	local nodeSource = draginfo.getDatabaseNode();
	
	if User.isHost() then
		local bProcessed = false;
		if Input.isAltPressed() then
			bProcessed = processClassDrop(sClass, sIdentity, draginfo);
		end
		if not bProcessed then
			local w = Interface.openWindow(draginfo.getShortcutData());
			if w then
				w.share(User.getIdentityOwner(sIdentity));
			end
		end
		return true;
	else
		processClassDrop(sClass, sIdentity, draginfo);
	end
end

function processClassDrop(sClass, sIdentity, draginfo)
	return ItemManager.handleAnyDrop("charsheet." .. sIdentity, draginfo);
end

function onDefaultDrop(sIdentity, draginfo)
	return CombatManager.onDrop("pc", "charsheet." .. sIdentity, draginfo);
end
