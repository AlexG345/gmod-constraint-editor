-- Contains:
--	Functions to send/receive data to/from the server
--	The exact behavior when receiving data from the server


local NT = ConstraintEditor.netTags
local BIT_COUNT = ConstraintEditor.netBitCounts


-- Simply send a net tag to the server
--
-- Arguments:
--	tag (int): a net tag, should be from the netTags table
function ConstraintEditor.NetSend( tag )
	if ConstraintEditor.NetStartWrite( tag ) then
		net.SendToServer()
	end
end


-- Checks whether the player is looking at a constraint text bubble or not, and gets the corresponding constraint creation ID.
--
-- Returns:
--	(boolean): true if a constraint is being hovered, false otherwise
--	hCID (int | nil): The hovered constraint ID
--	(string | nil): The hovered constraint type
local function isHoveringConstr()
	local hCID = ConstraintEditor.HoveredConstrInfo.ID
	return hCID and hCID >= 0, hCID, ConstraintEditor.HoveredConstrInfo.Type
end


local function getNetConstrIDs( constrCount )

	constrCount			= constrCount or net.ReadUInt( BIT_COUNT.ENT_ID )
	local minConstrID	= net.ReadUInt( BIT_COUNT.CREATION_ID )
	local diffBitCount	= net.ReadUInt( BIT_COUNT.BIT_COUNT_CREATION_ID )

	local constrIDs	= {}

	for i = 1, constrCount do
		local constrID = minConstrID + net.ReadUInt( diffBitCount )
		constrIDs[constrID] = constrID
	end

	return constrIDs

end


-- Different stuff is done depending on the net tag received from the server:
ConstraintEditor.netFunctions = {

	[NT.TOOLGUN_LEFT_CLICK] = function()

		local ent = net.ReadEntity()
		-- If the player is pressing shift, assume that they want to edit an extra entity on top of any currently edited ones.
		local clearSelection = not LocalPlayer():KeyDown( IN_SPEED )
		local constrHovered, constrID, constrType = isHoveringConstr()

		if constrHovered then
			ConstraintEditor.ToggleConstrs( { constrID }, constrType, clearSelection )
		else
			ConstraintEditor.ToggleEntity( ent, clearSelection )
		end

		return ent

	end,

	[NT.TOOLGUN_RIGHT_CLICK] = function()

		local constrHovered, constrID = isHoveringConstr()

		if constrHovered then
			if ConstraintEditor.NetStartWrite( NT.REMOVE_CONSTRS ) then
				ConstraintEditor.NetWriteConstrIDs( { [constrID] = true } )
				net.SendToServer()
			end
		else
			ConstraintEditor.SelectEntity( nil, true )
		end

	end,

	[NT.TOOLGUN_MIDDLE_CLICK] = function()

		local constrBrowser	= ConstraintEditor.GetConstrBrowser()
		local constrIDs		= constrBrowser and constrBrowser.selectionData.IDs

		local ent = LocalPlayer():GetEyeTrace().Entity

		if constrIDs and next( constrIDs ) ~= nil then
			-- Transfer the selected constraints of the selected entities (except ent) to ent
			if ConstraintEditor.NetStartWrite( NT.TRANSFER_CONSTRS ) then
				ConstraintEditor.NetWriteConstrIDs( constrIDs )
				net.WriteEntity( ent )
				net.SendToServer()
			end
		else
			-- Transfer all the constraints of the selected entities (except ent) to ent
			if ConstraintEditor.NetStartWrite( NT.TRANSFER_ALL_CONSTRS ) then
				net.WriteEntity( ent )
				net.SendToServer()
			end
		end

	end,

	[NT.REGISTER_CONSTRS] = function()

		local data = net.ReadTable()
		ConstraintEditor.RegisterConstrs( data )

		return data

	end,

	[NT.UNREGISTER_CONSTRS] = function()

		local constrIDs = getNetConstrIDs()

		ConstraintEditor.UnregisterConstrs( constrIDs )

		return constrIDs

	end,

	[NT.UNREGISTER_ALL_CONSTRS] = function()
		ConstraintEditor.UnregisterAllConstrs()
	end,

	[NT.FILL_CONSTR_EDITOR] = function()

		local data = net.ReadTable()
		local constrEditor = ConstraintEditor.GetConstrEditor()

		if data and IsValid( constrEditor ) then
			constrEditor:Fill( { values = data[1], args = data[2] } )
		end

		return data

	end,

	[NT.SELECT_CONSTRS] = function()

		local selection		= getNetConstrIDs()
		local constrType	= net.ReadString()
		local elimination	= getNetConstrIDs()

		ConstraintEditor.SelectConstrs( selection, constrType, elimination )

		return selection, constrType, elimination

	end,

}