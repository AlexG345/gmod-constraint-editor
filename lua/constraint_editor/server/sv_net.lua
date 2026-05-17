-- Contains:
--	Functions to send/receive data to/from the client
--	The behavior when receiving data from the client


util.AddNetworkString( "constraint_editor_net" )


local NT				= ConstraintEditor.netTags
local BIT_COUNT			= ConstraintEditor.netBitCounts


function ConstraintEditor.NetTargetIsValid( tar )

	local t = TypeID( tar )

	return (
		( t == TYPE_ENTITY and tar:IsPlayer() ) or
		( t == TYPE_TABLE ) or
		( t == TYPE_RECIPIENTFILTER )
	)

end


-- original function is from sh_net.lua
local oNetStartWrite = ConstraintEditor.NetStartWrite
function ConstraintEditor.NetStartWrite( tag, tar )
	return ConstraintEditor.NetTargetIsValid( tar ) and oNetStartWrite( tag )
end


-- Simply send a net tag to some client(s)
--
-- Arguments:
--	tag (int): a net tag, should be from the netTags table
--	tar: target client(s)
function ConstraintEditor.NetSend( tag, tar )
	if ConstraintEditor.NetStartWrite( tag, tar ) then
		net.Send( tar )
	end
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

	if ConstraintEditor.NetStartWrite( NT.FILL_CONSTR_EDITOR, ply ) then
		ConstraintEditor.NetWriteTable( { constrData, desc.Args } )
		net.Send( ply )
	end
end


local function getNetConstrs( ply, constrCount )

	constrCount			= constrCount or net.ReadUInt( BIT_COUNT.ENT_ID )
	local minConstrID	= net.ReadUInt( BIT_COUNT.CREATION_ID )
	local diffBitCount	= net.ReadUInt( BIT_COUNT.BIT_COUNT_CREATION_ID )

	local validConstrCount	= 0
	local validConstrs		= {}

	local badConstrIDs	= {}

	for _ = 1, constrCount do

		local constrID	= minConstrID + net.ReadUInt( diffBitCount )

		-- safety check
		local constr = ConstraintEditor.AccessConstraint( ply, ConstraintEditor.GetConstr( constrID ) )

		if not IsValid( constr ) then
			badConstrIDs[constrID] = true
		else
			validConstrCount = validConstrCount + 1
			table.insert( validConstrs, constr )
		end

	end

	if validConstrCount < constrCount then
		ConstraintEditor.UnregisterConstrIDs( badConstrIDs )
	end

	print("")
	print("[debug] getNetConstrs")
	MsgC( Color( 0, 255, 0 ), "\tValid constraints:\n" )
	PrintTable( validConstrs )
	print("")
	MsgC( Color( 255, 0, 0 ), "\tInvalid constraints:\n" )
	PrintTable( badConstrIDs )
	print("")

	return validConstrs, validConstrCount
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

	[NT.IGNORE_ENTITY] = function( ply )

		local ent = net.ReadEntity()
		ConstraintEditor.UnregisterConstrs( constraint.GetTable( ent ), ply )
		local t = ConstraintEditor.editedEnts
		if ( t[ply] and t[ply][ent] ) then t[ply][ent] = nil end
		ConstraintEditor.FindAndSetProperToolStage( ply )

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

		print("[debug] remove constrs, good constrs found:")
		PrintTable(constrs)

		ConstraintEditor.DeleteConstrs( constrs )

		return constrs

	end,

	[NT.UPDATE_CONSTRS] = function( ply )

		local newConstrData = ConstraintEditor.NetReadTable()
		local constrs = getNetConstrs( ply )
		ConstraintEditor.CreateConstrsFromConstrs( constrs, newConstrData, ply, true, true, true, true )

		return newConstrData, constrs
	end,

	[NT.DUPLIC_CONSTRS] = function( ply )

		local constrs = getNetConstrs( ply )
		ConstraintEditor.CreateConstrsFromConstrs( constrs, {}, ply, true, false, false, false )

		return constrs

	end,

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