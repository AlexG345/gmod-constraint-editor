include( "constraint_editor/sv_constr_data.lua" )
include( "constraint_editor/sv_constr_maker.lua" )
include( "constraint_editor/sv_misc.lua" )



local NT				= ConstraintEditor.NetTags
local BIT_COUNT			= ConstraintEditor.NetBitCounts

--[[
function ConstraintEditor.SendDataToClient( tag, data, ply, ent )

	if not isnumber( tag ) then return end
	if not ( isentity( ply ) and ply:IsPlayer() ) then return end

	net.Start( "constraint_editor_net" )
		net.WriteUInt( tag, BIT_COUNT.TAG )
		if istable( data ) then
			net.WriteTable( data )
		elseif isnumber( data ) then
			net.WriteUInt( data, BIT_COUNT.CONSTR_ID )
		elseif isentity( data ) then
			net.WriteEntity( data )
		end
	net.Send( ply )

end
]]


function ConstraintEditor.SendDataToClient( tag, ply, ... )

	if not ( isentity( ply ) and ply:IsPlayer() ) then return end

	ConstraintEditor.NetStartWrite( tag, ... )

	net.Send( ply )

end


-- Make constraints from constrs show up in ply's editor
function ConstraintEditor.AddEditedConstrs( constrs, ply )

	if not ply then return end
	local tool = ConstraintEditor.GetTool( ply )

	if not constrs or next( constrs ) == nil then
		if tool then tool:SetStage( 1 ) end
		return
	end

	local constr = select(2, next(constrs)) -- Choose first constraint in constrs (arg)
	local constrData, desc

	if #constrs > 1 then
		constrData, desc = ConstraintEditor.GetConstrDataDefault( constr, true )
	else
		constrData, desc = ConstraintEditor.GetConstrData( constr, true )
	end

	if not ( constrData and desc ) then return end

	if tool then tool:SetStage( 2 ) end

	ConstraintEditor.SendDataToClient(
		NT.FILL_EDITOR, ply,
		{ { constrData, desc.Args } }
	)

end


-- TODO: remove this (outdated)
-- Lets the player's editor edit all constraints under the same type as constr at once
-- A constr entity is needed, otherwise a table of known keys per constraint type would be needed.
-- With the current approach only a table of known values per constraint type is needed, and this table already exists.
-- TODO: check this function and related systems (ConstraintEditor.DefaultizeConstrData...) work
function ConstraintEditor.AddEditedConstrType( constr, ply )

	if not ply then return end

	local tool = ply.GetTool( ConstraintEditor.Mode )

	if not constr then
		if tool then tool:SetStage( 1 ) end
		return
	end

	local constrData, desc = ConstraintEditor.GetConstrData( constr )
	if not ( constrData and desc ) then return end

	-- TODO: make new stage for this edit
	if tool then tool:SetStage( 1 ) end
	constrData.constrID = nil
	ConstraintEditor.DefaultizeConstrData( constrData )
	ConstraintEditor.TransformConstrDataKeys( constrData, desc, true )

	ConstraintEditor.SendDataToClient(
		NT.FILL_EDITOR, ply,
		{ { constrData, desc.Args } }
	)

end


function ConstraintEditor.LeftClick( ent, ply )
	ConstraintEditor.SendDataToClient(
		NT.LEFT_CLICK, ply,
		{ ent }
	)
end


function ConstraintEditor.RightClick( ply )
	ConstraintEditor.SendDataToClient(
		NT.RIGHT_CLICK, ply
	)
end


function ConstraintEditor.Reload( ply )
	ConstraintEditor.SendDataToClient(
		NT.RELOAD, ply
	)
end


local function getNetConstrs( ply )

	local constrCount = net.ReadUInt( BIT_COUNT.ENT_COUNT )
	local validConstrCount = 0
	local constrs = {}
	local bci = BIT_COUNT.CONSTR_ID

	for i = 1, constrCount do

		local constrID = net.ReadUInt( bci )

		-- safety check
		local constr = ConstraintEditor.AccessConstraint( ply, constrID )

		if not constr then
			ConstraintEditor.SendDataToClient(
				NT.FORGET_CONSTR, ply,
				ConstraintEditor.ToNetConstrID( constrID )
			)
		elseif not IsValid ( constr ) then
			ConstraintEditor.ForgetConstr( constrID )
		else
			validConstrCount = validConstrCount + 1
			table.insert( constrs, constr )
		end

	end

	return constrs, validConstrCount
end


local netFunctions = {

	[NT.CLEAR_EDITED_ENTS] = function( ply )
		ConstraintEditor.ClearEditedEntities( ply )
	end,

	[NT.ADD_EDITED_ENTITY] = function( ply )
		local ent = net.ReadEntity()
		ConstraintEditor.AddEditedEntity( ent, ply, true )
	end,

	[NT.GET_DATA_FOR_EDITOR] = function( ply )
		local constrs = getNetConstrs( ply )
		if not constrs or next( constrs ) == nil then return end
		ConstraintEditor.AddEditedConstrs( constrs, ply )
	end,

	--[[
	[NT.GET_DEF_DATA_FOR_EDITOR] = function( ply )
		local constrs = getNetConstrs( ply )
		if not constrs or next( constrs ) == nil then return end
		ConstraintEditor.AddEditedConstrType( constrs[1], ply )
	end,
	]]

	[NT.REMOVE_CONSTR] = function( ply )
		local constrs = getNetConstrs( ply )
		for _, constr in ipairs( constrs ) do
			ConstraintEditor.DeleteConstr( constr )
		end
	end,

	[NT.UPDATE_CONSTR] = function( ply )
		local newConstrData = net.ReadTable()
		local constrs = getNetConstrs( ply )
		for _, constr in ipairs( constrs ) do
			ConstraintEditor.CreateConstrFromConstr( constr, newConstrData, ply, true, true, true, true )
		end
	end,

	[NT.DUPLIC_CONSTR] = function( ply )
		local constrs = getNetConstrs( ply )
		for _, constr in ipairs( constrs ) do
			ConstraintEditor.CreateConstrFromConstr( constr, {}, ply )
		end
	end,

	[NT.UPDATE_TYPE] = function( ply )
		local newConstrData = net.ReadTable()
		local constrType = net.ReadString()
		local editedEnts = ConstraintEditor.GetEditedEntities( ply )
		if not ( constrType and newConstrData and editedEnts ) then return end
		local constrs = ConstraintEditor.FindConstrsLinkedToEnts( editedEnts, constrType )
		for _, constr in pairs( constrs ) do
			constr = constr.Constraint
			constr = ConstraintEditor.AccessConstraint( ply, constr:GetCreationID() )
			local constrData = table.Copy( newConstrData )
			if constr then ConstraintEditor.CreateConstrFromConstr( constr, constrData, ply, true, true, true ) end
		end
	end,


	[NT.TRANSFER_CONSTR_ENTS] = function( ply )
		local newEnt	= ConstraintEditor.AccessEntity( ply, net.ReadEntity(), 3 )
		local constrs	= getNetConstrs( ply )

		local editedEnts = ConstraintEditor.GetEditedEntities( ply ) or {}
		if not ( newEnt and editedEnts ) then return end
		local entChange = {}
		for ent in pairs( editedEnts ) do entChange[ent] = newEnt end

		ConstraintEditor.AddEditedConstr( nil, ply )
		-- try transferring and stop once it's done once? (for k ,v ... do if change then return end end)
		ConstraintEditor.ChangeConstrsEnts( entChange, constrs, ply, true )
	end,

	[NT.TRANSFER_CONSTRS_ENTS] = function( ply )
		local newEnt = ConstraintEditor.AccessEntity( ply, net.ReadEntity(), 3 )

		local editedEnts = ConstraintEditor.GetEditedEntities( ply )
		if not ( newEnt and editedEnts ) then return end
		local entChange = {}
		for ent in pairs( editedEnts ) do entChange[ent] = newEnt end

		local constrs = ConstraintEditor.FindConstrsLinkedToEnts( editedEnts )

		ConstraintEditor.AddEditedConstr( nil, ply )
		ConstraintEditor.ChangeConstrsEnts( entChange, constrs, ply, true )
	end,
}

-- Client safety checks are here
function ConstraintEditor.HandleNetRequests()

	net.Receive( "constraint_editor_net", function( len, ply )

		if not ( ply and ply:IsPlayer() ) then return end

		local tag = net.ReadUInt( BIT_COUNT.TAG )
		netFunctions[tag]( ply )

	end )

end
