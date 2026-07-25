local NT				= ConstraintEditor.netTags
local TABLES_CLEANUP_CD	= 40 -- cooldown for cleaning up players data


-- Keys are constraint creation IDs, values are the associated constraint entities
ConstraintEditor.constrs = {}

-- Keys are players, values are table containing a table of edited entities and a cooldown
ConstraintEditor.playersData = {}

-- Time since the last table cleanup
ConstraintEditor.lastTablesCleanup = CurTime()


-------------------
--	Player info  --
-------------------

function ConstraintEditor.GetOrCreatePlayerData( ply )

	local t = ConstraintEditor.playersData[ply]

	if not t then
		t = { editedEnts = {}, nextOperationTime = CurTime() }
		ConstraintEditor.playersData[ply] = t
	end

	return t

end


-------------------
--  Constraints  --
-------------------


-- Stores a constraint by its creation ID so that it can then be quickly accessed
--
-- Argument:
--	constr (Entity): The constraint to be stored
--
-- Returns:
--	constrID (int): The creation ID of the constraint
function ConstraintEditor.RegisterConstr( constr )
	local constrID = constr:GetCreationID()

	ConstraintEditor.AddCallOnRemove( constr )
	ConstraintEditor.constrs[constrID] = constr

	return constrID
end


-- Stores constraints by their creation IDs so that they can then be quickly accessed
--
-- Argument:
--	constrs (table): Table with keys constraint creation IDs and values the associated constraints
function ConstraintEditor.RegisterConstrs( constrs )

	local CEConstrs = ConstraintEditor.constrs

	for constrID, constr in pairs( constrs ) do
		if not CEConstrs[constrID] then
			ConstraintEditor.AddCallOnRemove( constr )
			CEConstrs[constrID] = constr
		end
	end

end


-- Make some clients (optionally all) forget data related to some constraints
--
-- Argument:
--	constrs (table): Table whose values are the constraints we want to unregister
--	plys (Entity | table | CRecipientFilter | nil): Those who are affected by the unregister. If nil, all players are affected.
function ConstraintEditor.UnregisterConstrs( constrs, plys )

	local constrIDs = {}
	for _, constr in pairs( constrs ) do
		if istable( constr ) then constr = constr.Constraint end
		constrIDs[constr:GetCreationID()] = true
	end
	ConstraintEditor.UnregisterConstrIDs( constrIDs )

end



-- Make some clients (optionally all) forget data related to some constraints using their creation IDs
--
-- Argument:
--	constrIDs (table): Table whose keys are the constraint creation IDs we want to forget (if the associated value is not false)
--	plys (Entity | table | CRecipientFilter | nil): Those who are affected by the unregister. If nil, all players are affected.
function ConstraintEditor.UnregisterConstrIDs( constrIDs, plys )

	local unregistered = next( constrIDs ) ~= nil
	if not unregistered then return end

	if not plys then
		for constrID, _ in pairs( constrIDs ) do
			ConstraintEditor.constrs[constrID] = nil
		end
	end

	plys = plys or ConstraintEditor.GetEditorPlayers()
	if ConstraintEditor.NetStartWrite( NT.UNREGISTER_CONSTRS, plys ) then
		ConstraintEditor.NetWriteConstrIDs( constrIDs )
		net.Send( plys )
	end

end


-- Get a constraint using its creation ID
--
-- Argument:
--	constrID (int): The creation ID of the constraint
--
-- Returns:
--	(Entity): The constraint entity whose creation ID is constrID (arg)
function ConstraintEditor.GetConstr( constrID )
	return ConstraintEditor.constrs[constrID]
end




-----------------------
--  Edited Entities  --
-----------------------


-- Tries to let the player edit the constraints that are linked to the entity
function ConstraintEditor.RegisterEditedEntity( ent, ply )

	if not ConstraintEditor.AccessEntity( ply, ent, 1 ) then return end

	local playerData = ConstraintEditor.GetOrCreatePlayerData( ply )
	if playerData.editedEnts[ent] then return end
	playerData.editedEnts[ent] = ent

	local surfaceConstrsData, constrs = ConstraintEditor.GetEntSurfaceConstrsData( ent )

	ConstraintEditor.RegisterConstrs( constrs )

	if ConstraintEditor.NetStartWrite( NT.REGISTER_CONSTRS, ply ) then
		net.WriteTable( surfaceConstrsData )
		net.Send( ply )
	end

	local tool = ConstraintEditor.GetTool( ply )
	if tool then tool:SetStage( 1 ) end

end


function ConstraintEditor.UnregisterEditedEntity( ent, ply )

	local editedEnts = ConstraintEditor.GetEditedEntities( ply )
	if not ( editedEnts and editedEnts[ent] ) then return end
	editedEnts[ent] = nil

	-- unsharedConstrs: constraints linked to ent but not to other entities in the selection
	local unsharedConstrs = ConstraintEditor.FindConstrsNotLinkedToEnts( ent, ConstraintEditor.GetEditedEntities( ply ) )

	ConstraintEditor.UnregisterConstrs( unsharedConstrs, ply )

	ConstraintEditor.FindAndSetProperToolStage( ply )

end


function ConstraintEditor.ToggleEditedEntity( ent, ply )

	local playerData = ConstraintEditor.GetOrCreatePlayerData( ply )
	local editedEnts = playerData.editedEnts
	if editedEnts[ent] then
		ConstraintEditor.UnregisterEditedEntity( ent, ply )
	else
		ConstraintEditor.RegisterEditedEntity( ent, ply )
	end

end



-- Clears the player edited entities, handles clientside consequences
function ConstraintEditor.UnregisterAllEditedEntities( ply )

	local playerData = ConstraintEditor.playersData[ply]
	if not playerData then return end

	playerData.editedEnts = {}

	ConstraintEditor.NetSend( NT.UNREGISTER_ALL_CONSTRS, ply )

	local tool = ConstraintEditor.GetTool( ply )
	if tool then tool:SetStage( 0 ) end

end


function ConstraintEditor.GetEditedEntities( ply )
	local playerData = ConstraintEditor.playersData[ply]
	return playerData and playerData.editedEnts
end


-- TODO: upgrade this to target only players with non empty edited entities table?
function ConstraintEditor.GetEditorPlayers()
	return table.GetKeys( ConstraintEditor.playersData )
end


-- Removes a player's data if that player is invalid.
-- Removes invalid entities from players' edited entities.
function ConstraintEditor.CleanupTables()

	ConstraintEditor.lastTablesCleanup = CurTime()

	local playersData = ConstraintEditor.playersData

	for ply, playerData in pairs( playersData ) do
		if not IsValid( ply ) then
			playersData[ply] = nil
		else
			local editedEnts = playerData.editedEnts
			for editedEnt in pairs( editedEnts ) do
				if not IsValid( editedEnt ) then
					editedEnts[editedEnt] = nil
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