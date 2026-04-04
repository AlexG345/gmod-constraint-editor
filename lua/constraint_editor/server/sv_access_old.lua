--[[
include( "constraint_editor/sv_net.lua" )


local NT				= ConstraintEditor.netTags
local TABLES_CLEANUP_CD	= 30 -- cooldown for table cleanup


-- Keys are constraint IDs, values are tables containing:
-- 	ent: the constraint entity,
-- 	allowedPlayers: players who can ask server to edit the constraint
ConstraintEditor.constrs = {}

-- Keys are players, values are entities (props)
ConstraintEditor.editedEnts = {}

-- Time since last table cleanup
ConstraintEditor.lastTablesCleanup = CurTime()


------------------------------------------
--  Simplified safety checks            --
--  Replaces KnownConstr tables etc...  --
------------------------------------------


-- Checks if a player can access/tool an entity or not
--
-- Arguments:
--	ply (Player | nil): The player who's trying to access the entity
--	ent (Entity | nil): Any entity
--	button (int | nil): Mouse button used by ply (arg)
--
-- Returns:
--	ent (Entity | boolean): ent (arg) if ply (arg) can access it, or false
function ConstraintEditor.AccessEntity( ply, ent, button )

	button = button or 1
	return ply and isentity( ent ) and ( ent:IsValid() or ( game.SinglePlayer() and ent:IsWorld() ) ) and hook.Run( "CanTool", ply, { Entity = ent }, ConstraintEditor.Mode, button ) and ent or false

end

-- Checks if a player can access/tool a constraint or not, by checking if the player can access at least one of the entities linked to that constraint.
--
-- Arguments:
--	ply (Player | nil): The player who's trying to access the entity
--	constr (Entity | nil): Any constraint
--
-- Returns:
--	constr (Entity | boolean): constr (arg) if ply (arg) can access it, or false
function ConstraintEditor.AccessConstraint( ply, constr )

	local f = constr.GetConstrainedEntities
	local first, second = f and f( constr )
	return ( ConstraintEditor.AccessEntity( ply, first ) or ConstraintEditor.AccessEntity( ply, second ) ) and constr or false

end


---------------------
--  aaaaaaaaaaaaa  --
---------------------


-- Revoke all the constraint editing permissions of the player ply
function ConstraintEditor.ClearAccess( ply )

	if not ply then return end

	ConstraintEditor.editedEnts[ply] = nil

	for constrID, data in pairs( ConstraintEditor.constrs ) do
		local allowed = data.allowedPlayers
		allowed[ply] = nil
		if next( allowed ) == nil then ConstraintEditor.UnregisterConstr( constrID ) end
	end

end


-- Give or revoke the player's permission to edit the constraint through its creation ID or the entity itself
function ConstraintEditor.SetAccess( ply, constrID, allow, ent )

	constrID = constrID or ent and ent:GetCreationID()

	if not constrID then return end

	if not ConstraintEditor.constrs[constrID] then

		if not allow then return end
		ConstraintEditor.constrs[constrID] = { allowedPlayers = {}, ent = ent }

	end

	local plys = ConstraintEditor.constrs[constrID].allowedPlayers

	plys[ply] = allow and true or nil

	if next( plys ) == nil then ConstraintEditor.UnregisterConstr( constrID ) end

	if not allow then ConstraintEditor.NetSend( NT.UNREGISTER_CONSTRS, constrID, ply ) end

end


-- Transfers players permissions from constr to newConstr (as long as newConstr is still linked to their edited entities)
function ConstraintEditor.TransferAccess( constr, newConstr, checkLink )

	if not ( constr and newConstr ) then return end

	local constrID = constr:GetCreationID()
	local newConstrID = newConstr:GetCreationID()
	local data = ConstraintEditor.constrs[constrID]

	if not data then return end

	for ply in pairs( data.allowedPlayers ) do

		--ConstraintEditor.SetAccess( ply, constrID, false, constr )
		ConstraintEditor.SetAccess( ply, newConstrID, true, newConstr )

		-- Update the menus
		if ConstraintEditor.IsConstrLinkedToEnts( newConstr, ConstraintEditor.GetEditedEntities( ply ) ) then
			local surfaceConstrData = ConstraintEditor.GetSurfaceConstrData( newConstr )
			ConstraintEditor.NetSend( NT.REGISTER_CONSTRS, surfaceConstrData, ply )
		end

	end

end



-- Forgets all data related to this constrID (the associated constraint and the players editing permissions)
function ConstraintEditor.UnregisterConstr( constrID )

	local data = ConstraintEditor.constrs[constrID]

	if data then
		for ply in pairs( data.allowedPlayers ) do
			ConstraintEditor.NetSend( NT.UNREGISTER_CONSTRS, constrID, ply )
		end
	end

	ConstraintEditor.constrs[constrID] = nil

end


function ConstraintEditor.GetEditedEntities( ply )
	return ConstraintEditor.editedEnts[ply]
end


-- Tries to give to the player edit permissions for all constraints attached to the entity
-- Has safety checks
function ConstraintEditor.RegisterEditedEntity( ent, ply )

	if not ConstraintEditor.AccessEntity( ply, ent, 1 ) then return end

	if not ConstraintEditor.editedEnts[ply] then ConstraintEditor.editedEnts[ply] = {} end

	ConstraintEditor.editedEnts[ply][ent] = ent

	local surfaceConstrsData, constrs = ConstraintEditor.GetEntSurfaceConstrsData( ent )
	local tool = ply.GetTool and ply:GetTool( ConstraintEditor.Mode )

	if tool then tool:SetStage( 1 ) end

	for constrID, constr in pairs( constrs ) do
		ConstraintEditor.SetAccess( ply, constrID, true, constr )
	end
	ConstraintEditor.NetSend( NT.REGISTER_CONSTRS, surfaceConstrsData, ply )

end


-- Clears the player edited entities, handles clientside consequences
function ConstraintEditor.UnregisterAllEditedEntities( ply )

	ConstraintEditor.ClearAccess(ply)
	ConstraintEditor.NetSend( NT.UNREGISTER_ALL_CONSTRS, nil, ply )
	local tool = ply.GetTool and ply:GetTool( ConstraintEditor.Mode )
	if tool then tool:SetStage( 0 ) end

end


-- Forgets constrIDs:
--		that have no related data
-- 		whose associated constraint is not valid (e.g. has been removed)
-- 		that have no player permissions
-- Also clears EditedEnts if player or entity is invalid
function ConstraintEditor.CleanupTables()

	ConstraintEditor.lastTablesCleanup = CurTime()

	for constrID, data in pairs( ConstraintEditor.constrs ) do
		if not data or not IsValid( data.ent ) or next( data.allowedPlayers ) == nil then
			ConstraintEditor.UnregisterConstr( constrID )
		end
	end

	for ply, entities in pairs( ConstraintEditor.editedEnts ) do
		if not IsValid( ply ) then
			ConstraintEditor.ClearAccess( ply )
		else
			for ent in pairs( entities ) do
				if not IsValid( ent ) then
					ConstraintEditor.editedEnts[ply][ent] = nil
				end
			end
		end
	end

end


-- Same as CleanupTables but with a cooldown
function ConstraintEditor.TryCleanupTables()
	if CurTime() - ( ConstraintEditor.lastTablesCleanup or 0 ) < TABLES_CLEANUP_CD then return end

	ConstraintEditor.CleanupTables()
end


-- Deletes a constraint entity and data associated to its constrID
function ConstraintEditor.DeleteConstr( constr )
	constr.CEInvalid = true
	local constrID = constr:GetCreationID()
	ConstraintEditor.UnregisterConstr( constrID )
	SafeRemoveEntity( constr )
end
]]