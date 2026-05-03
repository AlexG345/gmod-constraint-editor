-- Contains:
--	Functions to send/receive data to/from the client
--	The behavior when receiving data from the client


util.AddNetworkString( "constraint_editor_net" )


local NT				= ConstraintEditor.netTags
local BIT_COUNT			= ConstraintEditor.netBitCounts


function ConstraintEditor.NetSend( tag, targets, ... )

	local t = TypeID( targets )

	if not (
		(
			( t == TYPE_ENTITY and targets:IsPlayer() ) or
			( t == TYPE_TABLE ) or
			( t == TYPE_RECIPIENTFILTER )
		) and
		ConstraintEditor.NetStartWrite( tag, ... )
	) then return end

	net.Send( { Entity(1) } )

end


function ConstraintEditor.NetBroadcast( tag, ... )

	if not ConstraintEditor.NetStartWrite( tag, ... ) then return end

	net.Broadcast()

end


-- Fill ply's constraint editor using data from a constraint
function ConstraintEditor.FillEditorWithConstr( constr, ply, getDefault )

	if not ply then return end
	local tool = ConstraintEditor.GetTool( ply )

	if not constr then
		if tool then tool:SetStage( 1 ) end
		return
	end

	local constrData, desc

	if getDefault then
		constrData, desc = ConstraintEditor.GetConstrDataDefault( constr, true )
	else
		constrData, desc = ConstraintEditor.GetConstrData( constr, true )
	end

	if not ( constrData and desc ) then return end

	if tool then tool:SetStage( 2 ) end

	ConstraintEditor.NetSend(
		NT.FILL_CONSTR_EDITOR, ply,
		{ { constrData, desc.Args } }
	)

end


local function getNetConstrs( ply, constrCount )

	constrCount				= constrCount or net.ReadUInt( BIT_COUNT.ENT_ID )
	local validConstrCount	= 0
	local constrs			= {}
	local bit_count			= BIT_COUNT.CREATION_ID

	local badConstrIDs = {}

	for i = 1, constrCount do

		local constrID = net.ReadUInt( bit_count )

		-- safety check
		local constr = ConstraintEditor.AccessConstraint( ply, ConstraintEditor.GetConstr( constrID ) )

		if not IsValid( constr ) then
			table.insert( badConstrIDs, { [constrID] = true } )
		else
			validConstrCount = validConstrCount + 1
			table.insert( constrs, constr )
		end

		if validConstrCount < constrCount then
			ConstraintEditor.UnregisterConstrs( badConstrIDs )
		end

		print( "getNetConstrs loop: ", constrID, ConstraintEditor.GetConstr( constrID ), constr )

	end

	return constrs, validConstrCount
end


-- Different stuff is done depending on the net tag received from the client:
ConstraintEditor.netFunctions = {

	[NT.CLEAR_ENTITY_SELECTION] = function( ply )
		ConstraintEditor.UnregisterAllEditedEntities( ply )
	end,

	[NT.SELECT_ENTITY] = function( ply )

		local ent = net.ReadEntity()
		ConstraintEditor.RegisterEditedEntity( ent, ply, true )

		return ent

	end,

	[NT.TOGGLE_ENTITY] = function( ply )

		local ent = net.ReadEntity()
		ConstraintEditor.ToggleEditedEntity( ent, ply )

		return ent

	end,

	[NT.FILL_CONSTR_EDITOR] = function( ply )

		local constr		= getNetConstrs( ply, 1 )[1]
		local getDefault	= net.ReadBool()

		if not constr then return end
		ConstraintEditor.FillEditorWithConstr( constr, ply, getDefault )

		return constr, getDefault

	end,

	[NT.REMOVE_CONSTRS] = function( ply )

		local constrs = getNetConstrs( ply )

		for _, constr in ipairs( constrs ) do
			ConstraintEditor.DeleteConstr( constr )
		end

		return constrs

	end,

	[NT.UPDATE_CONSTRS] = function( ply )

		local newConstrData = net.ReadTable()
		local constrs = getNetConstrs( ply )
		ConstraintEditor.CreateConstrsFromConstrs( constrs, newConstrData, ply, true, true, true, true )

		return newConstrData, constrs
	end,

	[NT.DUPLIC_CONSTRS] = function( ply )

		local constrs = getNetConstrs( ply )
		ConstraintEditor.CreateConstrsFromConstrs( constrs, newConstrData, ply, true, true, true, true )

		return constrs

	end,

	--[[
	[NT.UPDATE_TYPE] = function( ply )
		local newConstrData = net.ReadTable()
		local constrType = net.ReadString()
		local editedEnts = ConstraintEditor.GetEditedEntities( ply )
		if not ( constrType and newConstrData and editedEnts ) then return end
		local constrs = ConstraintEditor.FindConstrsLinkedToEnts( editedEnts, constrType )
		for _, constr in pairs( constrs ) do
			constr = constr.Constraint
			constr = ConstraintEditor.AccessConstraint( ply, constr )
			local constrData = table.Copy( newConstrData )
			if constr then ConstraintEditor.CreateConstrsFromConstrs( constr, constrData, ply, true, true, true ) end
		end
	end,
	]]

	[NT.TRANSFER_CONSTRS] = function( ply )

		local newEnt	= ConstraintEditor.AccessEntity( ply, net.ReadEntity(), 3 )
		local constrs	= getNetConstrs( ply )

		local editedEnts = ConstraintEditor.GetEditedEntities( ply ) or {}
		if not ( newEnt and editedEnts ) then return end
		local entChange = {}
		for ent in pairs( editedEnts ) do entChange[ent] = newEnt end

		ConstraintEditor.FillEditorWithConstr( nil, ply )
		-- try transferring and stop once it's done once? (for k ,v ... do if change then return end end)
		ConstraintEditor.ChangeConstrsEnts( entChange, constrs, ply, true )

		return newEnt, constrs

	end,

	[NT.TRANSFER_ALL_CONSTRS] = function( ply )

		local newEnt = ConstraintEditor.AccessEntity( ply, net.ReadEntity(), 3 )

		local editedEnts = ConstraintEditor.GetEditedEntities( ply )
		if not ( newEnt and editedEnts ) then return end
		local entChange = {}
		for ent in pairs( editedEnts ) do entChange[ent] = newEnt end

		local constrs = ConstraintEditor.FindConstrsLinkedToEnts( editedEnts )

		ConstraintEditor.FillEditorWithConstr( nil, ply )
		ConstraintEditor.ChangeConstrsEnts( entChange, constrs, ply, true )


		return newEnt

	end,
}