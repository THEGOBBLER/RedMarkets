-- 
-- Please see the license.html file included with this distribution for 
-- attribution and copyright information.
--

local srcnode = nil;
local srcnodetype = "string";
local srcnodename = "";

local nBaseIndex = 0;
local nCycleIndex = 0;

local icons = {};
local values = {};
local tooltips = {};

function onInit()
	-- Get any custom fields
	if parameters then
		if parameters[1].icons then
			icons = StringManager.split(parameters[1].icons[1], "|");
		end
		if parameters[1].values then
			values = StringManager.split(parameters[1].values[1], "|");
		end

		if parameters[1].tooltipsres then
			local tooltipsres = StringManager.split(parameters[1].tooltipsres[1], "|");
			for _,v in ipairs(tooltipsres) do
				table.insert(tooltips, Interface.getString(v));
			end
		elseif parameters[1].tooltips then
			tooltips = StringManager.split(parameters[1].tooltips[1], "|");
		end

		if parameters[1].nodefault then
			nBaseIndex = 1;
		else
			if parameters[1].defaulticon then
				icons[0] = parameters[1].defaulticon[1];
				values[0] = "";
			end
			if parameters[1].defaulttooltipres then
				tooltips[0] = Interface.getString(parameters[1].defaulttooltipres[1]);
			elseif parameters[1].defaulttooltip then
				tooltips[0] = parameters[1].defaulttooltip[1];
			end
		end
	end
	
	-- SET ACCESS RIGHTS
	local bLocked = false;
	
	-- SET UP DATA CONNECTION
	if not sourceless then
		srcnodename = getName();
		if source then
			if source[1].name then
				srcnodename = source[1].name[1];
			end
			if source[1].type then
				if source[1].type[1] == "number" then
					srcnodetype = "number";
				end
			end
		end
	end
	if srcnodename ~= "" then
		-- DETERMINE DB READ-ONLY STATE
		local node = window.getDatabaseNode();
		if node.isReadOnly() then
			bLocked = true;
		end

		-- LINK TO DATABASE NODE, AND FUTURE UPDATES
		srcnode = node.getChild(srcnodename);
		if srcnode then
			if srcnode.getType() ~= srcnodetype then
				print("button_iconcycler (" .. getName() .. "): Database node type mismatch");
				srcnode = nil;
			end
		else
			srcnode = node.createChild(srcnodename, srcnodetype);
			if srcnode then
				if srcnodetype == "number" then
					if nBaseIndex ~= 0 then
						srcnode.setValue(nBaseIndex);
					end
				else
					if values[nBaseIndex] ~= "" then
						srcnode.setValue(values[nBaseIndex]);
					end
				end
			end
		end
		if srcnode then
			srcnode.onUpdate = update;
		elseif node then
			node.onChildAdded = registerUpdate;
		end
		
		-- SYNCHRONIZE DATA VALUES
		synchData();
	end
	
	-- Set the correct read only value
	if bLocked then
		setReadOnly(bLocked);
	end
	
	if self.onCustomInit then
		self.onCustomInit();
	end
	
	-- UPDATE DISPLAY
	updateDisplay();
end

function registerUpdate(nodeSource, nodeChild)
	if nodeChild.getName() == srcnodename then
		nodeSource.onChildAdded = function () end;
		nodeChild.onUpdate = update;
		srcnode = nodeChild;
		update();
	end
end

function synchData()
	if srcnodetype == "number" then
		if srcnode then
			nCycleIndex = srcnode.getValue();
		else
			nCycleIndex = nBaseIndex;
		end
	else
		local srcval = "";
		if srcnode then srcval = srcnode.getValue(); end
		local nMatch = nBaseIndex;
		for k, v in pairs(values) do
			if v == srcval then
				nMatch = k;
			end
		end
		nCycleIndex = nMatch;
	end
end

function updateDisplay()
	if not icons[nCycleIndex] then
		nCycleIndex = nBaseIndex;
	end
	setIcon(icons[nCycleIndex] or "");
	setTooltipText(tooltips[nCycleIndex] or "");
end

function update()
	synchData();
	updateDisplay();
	if self.onValueChanged then
		self.onValueChanged();
	end
end

function getSourceNode()
	return srcnode;
end

function setIndex(srcval)
	if type(srcval) ~= "number" then
		return;
	end

	if srcnode then
		if srcnodetype == "number" then
			srcnode.setValue(srcval);
		else
			if srcval >= nBaseIndex and srcval <= #values then
				srcnode.setValue(values[srcval]);
			else
				srcnode.setValue("");
			end
		end
	else
		if srcval >= nBaseIndex and srcval <= #icons then
			nCycleIndex = srcval;
		else
			nCycleIndex = nBaseIndex;
		end
		updateDisplay();
		if self.onValueChanged then
			self.onValueChanged();
		end
	end

end

function setStringValue(srcval)
	if type(srcval) ~= "string" then
		return;
	end
	
	if srcnode then
		if srcnodetype == "number" then
			if srcnode then
				local nMatch = nBaseIndex;
				for k, v in pairs(values) do
					if v == srcval then
						nMatch = k;
					end
				end
				srcnode.setValue(nMatch);
			end
		else
			if srcnode then
				srcnode.setValue(srcval);
			end
		end
	else
		local nMatch = nBaseIndex;
		for k, v in pairs(values) do
			if v == srcval then
				nMatch = k;
			end
		end
		nCycleIndex = nMatch;
	end
end

function getIndex()
	return nCycleIndex;
end

function getStringValue()
	if nCycleIndex >= nBaseIndex and nCycleIndex <= #values then
		return values[nCycleIndex];
	end
	return "";
end

function cycleIcon(bBackward)
	if bBackward then
		if nCycleIndex > nBaseIndex then
			nCycleIndex = nCycleIndex - 1;
		else
			nCycleIndex = #icons;
		end
	else
		if nCycleIndex < #icons then
			nCycleIndex = nCycleIndex + 1;
		else
			nCycleIndex = nBaseIndex;
		end
	end

	if srcnode then
		if srcnodetype == "number" then
			srcnode.setValue(nCycleIndex);
		else
			srcnode.setValue(getStringValue());
		end
	else
		updateDisplay();
		if self.onValueChanged then
			self.onValueChanged();
		end
	end
end

function onClickDown(button, x, y)

	if Input.isControlPressed() then
		Debug.console("ctrl pressed")
		srcnode.setValue("icon_blank")
	end
	return true;
end

function onClickRelease(button, x, y)
	if not isReadOnly() then
		cycleIcon(Input.isControlPressed());
	end
	return true;
end

function addState(sIcon, sValue, sTooltip)
	local nState = #icons + 1;
	
	icons[nState] = sIcon;
	values[nState] = sValue;
	tooltips[nState] = sTooltip;
end
