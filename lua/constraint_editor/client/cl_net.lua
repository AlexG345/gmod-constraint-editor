local NT = ConstraintEditor.netTags
local BIT_COUNT = ConstraintEditor.netBitCounts


function ConstraintEditor.NetSend( tag, ... )

	if not ConstraintEditor.NetStartWrite( tag, ... ) then return end

	print( "[debug] CLIENT -> SERVER" )
	print( "tag: ", ConstraintEditor.GetNetTagName( tag ) .. "(" .. tag .. ")" )
	PrintTable( {
		args = { ... }
	} )
	print( "" )

	net.SendToServer()

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

	constrCount		= constrCount or net.ReadUInt( BIT_COUNT.ENT_ID )
	local constrIDs	= {}
	local bit_count	= BIT_COUNT.CREATION_ID

	for i = 1, constrCount do
		local constrID = net.ReadUInt( bit_count )
		constrIDs[constrID] = constrID
	end

	return constrIDs

end


-- Different stuff is done depending on the net tag received from the server:
local netFunctions = {

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

		local constrHovered, constrID = isHoveringConstr()

		print( ConstraintEditor.ToNetConstrIDs( { [constrID] = true } ) )

		if constrHovered then
			ConstraintEditor.NetSend(
				NT.REMOVE_CONSTRS,
				ConstraintEditor.ToNetConstrIDs( { [constrID] = true } )
			)
		else
			ConstraintEditor.SelectEntity( nil, true )
		end
	end,

	[NT.TOOLGUN_MIDDLE_CLICK] = function()

		local constrBrowser	= ConstraintEditor.GetConstrBrowser()
		local constrIDs		= constrBrowser and constrBrowser.selectionData.IDs

		local ply = LocalPlayer()
		local ent = ply:GetEyeTrace().Entity

		if constrIDs and next( constrIDs ) ~= nil then
			-- Transfer the selected constraints of the selected entities (except ent) to ent
			ConstraintEditor.NetSend(
				NT.TRANSFER_CONSTRS,
				ConstraintEditor.ToNetConstrIDs( constrIDs ),
				{ ent }
			)
		else
			-- Transfer all the constraints of the selected entities (except ent) to ent
			ConstraintEditor.NetSend(
				NT.TRANSFER_ALL_CONSTRS,
				{ ent }
			)
		end

	end,

	[NT.REGISTER_CONSTRS] = function()
		local data = net.ReadTable()
		ConstraintEditor.RegisterConstrs( data )
	end,

	[NT.UNREGISTER_CONSTRS] = function()

		local constrIDs = getNetConstrIDs()
		print("received: unregister constrs")
		PrintTable( constrIDs )

		ConstraintEditor.UnregisterConstrs( constrIDs )

	end,


	[NT.UNREGISTER_ALL_CONSTRS] = function()

		ConstraintEditor.constrs = {}

		local constrBrowser	= ConstraintEditor.GetConstrBrowser()

		if IsValid( constrBrowser ) then
			constrBrowser:Clear()
		end

	end,

	[NT.FILL_CONSTR_EDITOR] = function()

		local data = net.ReadTable()
		local constrEditor = ConstraintEditor.GetConstrEditor()

		if data and IsValid( constrEditor ) then
			constrEditor:Fill( { values = data[1], args = data[2] } )
		end

	end,

}


-- Start listening to net messages
function ConstraintEditor.HandleNetRequests()

	net.Receive( "constraint_editor_net", function( len, _ )

		local tag = net.ReadUInt( BIT_COUNT.TAG )
		netFunctions[tag]()

	end )

end


