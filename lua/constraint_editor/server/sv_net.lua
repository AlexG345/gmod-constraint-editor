-- Contains:
--	Functions to send/receive data to/from the client
--	The behavior when receiving data from the client (moving logic away from this file would be great)


util.AddNetworkString( "constraint_editor_net" )


CreateConVar(
	"sv_constraint_editor_cooldown_enabled",
	game.SinglePlayer() and "0" or "1",
	{},
	"Limit the rate at which players can do constraint operations (using constraint editor).",
	0, 1
)


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

	local maxConstrCountCVar	= GetConVar( "sv_constraint_editor_max_edit" )
	local maxConstrCount		= maxConstrCountCVar and maxConstrCountCVar:GetInt() or 2048

	-- The max constraint count includes invalid constraints.
	-- This is to stop the server from processing thousands
	-- of invalid constraints even with a low max constr count
	constrCount = constrCount or net.ReadUInt( BIT_COUNT.ENT_ID )
	if constrCount > maxConstrCount then constrCount = maxConstrCount end

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
			validConstrs[validConstrCount] = constr
		end

	end

	if validConstrCount < constrCount then
		ConstraintEditor.UnregisterConstrIDs( badConstrIDs )
	end

	-- print("\n[debug] getNetConstrs")
	-- MsgC( Color( 0, 255, 0 ), "\tValid constraints:\n" )
	-- PrintTable( validConstrs )
	-- MsgC( Color( 255, 0, 0 ), "\n\tInvalid constraints:\n" )
	-- PrintTable( badConstrIDs )
	-- print("")

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

	end,

	[NT.TOGGLE_ENTITY] = function( ply )

		local ent = net.ReadEntity()
		ConstraintEditor.ToggleEditedEntity( ent, ply )

	end,

	[NT.IGNORE_ENTITY] = function( ply )

		local ent = net.ReadEntity()
		ConstraintEditor.UnregisterConstrs( constraint.GetTable( ent ), ply )

		local playerData = ConstraintEditor.playersData[ply]
		if not playerData then return end

		playerData.editedEnts[ent] = nil
		ConstraintEditor.FindAndSetProperToolStage( ply )

	end,

	[NT.FILL_CONSTR_EDITOR] = function( ply )

		local constr		= getNetConstrs( ply, 1 )[1]
		local getDefault	= net.ReadBool()

		if not constr then return end
		ConstraintEditor.FillEditorWithConstr( constr, ply, getDefault )

	end,

	[NT.REMOVE_CONSTRS] = function( ply )

		local constrs, constrCount = getNetConstrs( ply )

		ConstraintEditor.DeleteConstrs( constrs )

		return constrCount

	end,

	[NT.UPDATE_CONSTRS] = function( ply )

		local newConstrData = ConstraintEditor.NetReadTable()
		local constrs, constrCount = getNetConstrs( ply )
		ConstraintEditor.CreateConstrsFromConstrs( constrs, newConstrData, ply, true, true, true, true )

		return constrCount
	end,

	[NT.DUPLIC_CONSTRS] = function( ply )

		local constrs, constrCount = getNetConstrs( ply )

		local maxDuplicateCVar	= GetConVar( "sv_constraint_editor_max_duplicate" )
		local maxDuplicate		= maxDuplicateCVar and maxDuplicateCVar:GetInt() or 2048
		if constrCount > maxDuplicate then return end

		ConstraintEditor.CreateConstrsFromConstrs( constrs, {}, ply, true, false, false, false )

		return constrCount

	end,

	[NT.TRANSFER_CONSTRS] = function( ply )

		local constrs, constrCount	= getNetConstrs( ply )
		local newEnt				= ConstraintEditor.AccessEntity( ply, net.ReadEntity(), 3 )
		local newBone				= net.ReadUInt( ConstraintEditor.netBitCounts.PHYS_NUM )

		local editedEnts = ConstraintEditor.GetEditedEntities( ply ) or {}
		if not ( newEnt and editedEnts ) then return end

		local attachsChange = {}
		local attachChange = { ent = newEnt, bone = newBone }

		for ent in pairs( editedEnts ) do
			attachsChange[ent] = attachChange
		end

		ConstraintEditor.FillEditorWithConstr( nil, ply )

		local delete
		if ply then
			local tool = ConstraintEditor.GetTool( ply )
			delete = tool and tool:GetClientBool( "transfer_delete", true )
		end

		ConstraintEditor.ChangeConstrsAttachs( attachsChange, constrs, ply, delete )

		return constrCount

	end,

	-- This is mostly the same as above, but all constraints linked to the edited entities are affected instead.
	[NT.TRANSFER_ALL_CONSTRS] = function( ply )

		local newEnt	= ConstraintEditor.AccessEntity( ply, net.ReadEntity(), 3 )
		local newBone	= net.ReadUInt( ConstraintEditor.netBitCounts.PHYS_NUM )

		local editedEnts = ConstraintEditor.GetEditedEntities( ply )
		if not ( newEnt and editedEnts ) then return end

		local attachsChange	= {}
		local attachChange	= { ent = newEnt, bone = newBone }
		for ent in pairs( editedEnts ) do
			attachsChange[ent] = attachChange
		end

		local constrs = ConstraintEditor.FindConstrsLinkedToEnts( editedEnts )

		ConstraintEditor.FillEditorWithConstr( nil, ply )

		local delete
		if ply then
			local tool = ConstraintEditor.GetTool( ply )
			delete = tool and tool:GetClientBool( "transfer_delete", true )
		end

		ConstraintEditor.ChangeConstrsAttachs( attachsChange, constrs, ply, delete )

		return #constrs

	end,
}


local operationNetTags = {
	[NT.UPDATE_CONSTRS]			= true,
	[NT.REMOVE_CONSTRS]			= true,
	[NT.DUPLIC_CONSTRS]			= true,
	[NT.TRANSFER_CONSTRS]		= true,
	[NT.TRANSFER_ALL_CONSTRS]	= true,
}


-- Call this to start listening to net messages
function ConstraintEditor.HandleNetRequests()

	net.Receive( "constraint_editor_net", function( len, ply )

		if not ( ply and ply:IsPlayer() ) then return end

		local tag		= net.ReadUInt( BIT_COUNT.TAG )
		local netFunc	= tag and ConstraintEditor.netFunctions[tag]

		if not netFunc then return end

		local do_cooldown
		if operationNetTags[tag] then
			local cooldownCVar = GetConVar( "sv_constraint_editor_cooldown_enabled" )
			do_cooldown = cooldownCVar and cooldownCVar:GetBool()
		end

		if do_cooldown then
			local playerData	= ConstraintEditor.GetOrCreatePlayerData( ply )
			local cooldown		= playerData.nextOperationTime - CurTime()
			if cooldown > 0 then
				ply:ChatPrint(
					string.format( "Constraint Editor - Please wait %.2f more seconds before your next action.", cooldown )
				)
				return
			end

			local affectedConstrs			= netFunc( ply )
			playerData.nextOperationTime	= CurTime() + 0.05 + 0.06 * math.sqrt( affectedConstrs or 0 )
		else
			netFunc( ply )
		end

		--netDebug( true, false, tag )

	end )

end


ConstraintEditor.HandleNetRequests()