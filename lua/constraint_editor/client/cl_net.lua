-- Contains:
--	Functions to send/receive data to/from the server
--	The exact behavior when receiving data from the server


local NT = ConstraintEditor.netTags
local BIT_COUNT = ConstraintEditor.netBitCounts


-- Starts a net message with a tag and optional arguments.
-- Note that this does not send the message, only starts it and writes some data.
--
-- Arguments:
--	tag (int): A number from the ConstraintEditor.netTags table. Used to describe the goal of the message and the data held by it.
--	... (tuple of tables | nil): A tuple of tables in the form { v, arg }, where:
--		v (string | unsigned integer | table | boolean | entity | vector | angle | matrix | color) is some data that you want to send
--		arg (int | nil) is the second argument to be passed to the net write function (e.g. the maximum bit count of a constraint creation ID...)
function ConstraintEditor.NetStartWrite( tag )

	if not isnumber( tag ) then return false end

	-- netDebug( true, true, tag, nil )

	net.Start( "constraint_editor_net" )

		net.WriteUInt( tag, BIT_COUNT.TAG )

	return true

end



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

	for _ = 1, constrCount do
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

	end,

	[NT.TOOLGUN_RIGHT_CLICK] = function()

		local ent = net.ReadEntity()
		local constrHovered, constrID = isHoveringConstr()

		if LocalPlayer():KeyDown( IN_SPEED ) then
			ConstraintEditor.IgnoreEntity( ent )
		elseif constrHovered then
			if ConstraintEditor.NetStartWrite( NT.REMOVE_CONSTRS ) then
				ConstraintEditor.NetWriteConstrIDs( { [constrID] = true } )
				net.SendToServer()
			end
		else
			ConstraintEditor.SelectEntity( nil, true )
		end

	end,

	[NT.TOOLGUN_RELOAD] = function()

		local ent	= net.ReadEntity() --LocalPlayer():GetEyeTrace().Entity
		local bone	= net.ReadUInt( ConstraintEditor.netBitCounts.PHYS_NUM )

		local constrBrowser	= ConstraintEditor.GetConstrBrowser()
		local constrIDs		= constrBrowser and constrBrowser.selectionData.IDs

		if constrIDs and next( constrIDs ) ~= nil then
			-- Transfer the selected constraints of the selected entities (except ent) to ent
			if ConstraintEditor.NetStartWrite( NT.TRANSFER_CONSTRS ) then
				ConstraintEditor.NetWriteConstrIDs( constrIDs )
				net.WriteEntity( ent )
				net.WriteUInt( bone, ConstraintEditor.netBitCounts.PHYS_NUM )
				net.SendToServer()
			end
		else
			-- Transfer all the constraints of the selected entities (except ent) to ent
			if ConstraintEditor.NetStartWrite( NT.TRANSFER_ALL_CONSTRS ) then
				net.WriteEntity( ent )
				net.WriteUInt( bone, ConstraintEditor.netBitCounts.PHYS_NUM )
				net.SendToServer()
			end
		end

	end,

	[NT.REGISTER_CONSTRS] = function()

		local data = net.ReadTable()
		ConstraintEditor.RegisterConstrs( data )

	end,

	[NT.UNREGISTER_CONSTRS] = function()

		local constrIDs = getNetConstrIDs()

		ConstraintEditor.UnregisterConstrs( constrIDs )

	end,

	[NT.UNREGISTER_ALL_CONSTRS] = function()
		ConstraintEditor.UnregisterAllConstrs()
	end,

	[NT.FILL_CONSTR_EDITOR] = function()

		local data			= ConstraintEditor.NetReadTable()
		local constrBrowser = ConstraintEditor.GetConstrBrowser()
		local constrEditor	= ConstraintEditor.GetConstrEditor()

		if data and IsValid( constrEditor ) then
			constrEditor:Fill( { values = data[1], args = data[2] }, constrBrowser.selectionData.dataType )
		end

	end,

	[NT.SELECT_CONSTRS] = function()

		local selection		= getNetConstrIDs()
		local constrType	= net.ReadString()
		local elimination	= getNetConstrIDs()

		ConstraintEditor.SelectConstrs( selection, constrType, elimination )

	end,

}


-- Call this to start listening to net messages
function ConstraintEditor.HandleNetRequests()

	net.Receive( "constraint_editor_net", function( len, ply )

		local tag = net.ReadUInt( BIT_COUNT.TAG )
		ConstraintEditor.netFunctions[tag]( ply )

		--netDebug( true, false, tag )

	end )

end


ConstraintEditor.HandleNetRequests()