-- 
-- Please see the license.html file included with this distribution for 
-- attribution and copyright information.
--

function onInit()
	self.onSlashCommand = ChatManager.onSlashCommand;
end

function onDeliverMessage(msg, mode)
	local sIcon = nil;
	
	if mode == "chat" then
		if User.isHost() then
			sIcon = "portrait_gm_token";

			if not msg.sender or (msg.sender == "" or msg.sender == User.getUsername()) then
				gmid, isgm = GmIdentityManager.getCurrent();
				msg.sender = gmid;
				if isgm then
					msg.font = "chatgmfont";
				else
					msg.font = "chatnpcfont";
				end
			else
				msg.font = "chatnpcfont";
			end
		else
			local sCurrentId = User.getCurrentIdentity();
			if sCurrentId then
				sIcon = "portrait_" .. sCurrentId .. "_chat";
			end
		end
	elseif mode == "emote" then
		if User.isHost() then
			local gmid, isgm = GmIdentityManager.getCurrent();
			if not isgm then
				msg.sender = "";
				msg.text = gmid .. " " .. msg.text;
			end
		end
	end
	
	if OptionsManager.isOption("PCHT", "on") then
		msg.icon = sIcon;
	end
	
	if window.language and mode == "chat" and LanguageManager.checkLangChat(msg, window.language.getValue()) then
		return false;
	end
	
	return msg;
end

function onTab()
	ChatManager.doUserAutoComplete(self);
end
