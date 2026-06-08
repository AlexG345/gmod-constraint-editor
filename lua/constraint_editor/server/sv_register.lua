local NT				= ConstraintEditor.netTags
local TABLES_CLEANUP_CD	= 30 -- cooldown for table cleanup


-- Keys are constraint creation IDs, values are the associated constraint entities
ConstraintEditor.constrs = {}

-- Keys are players, values are entities (props)
ConstraintEditor.editedEnts = {}

-- Time since the last table cleanup
ConstraintEditor.lastTablesCleanup = CurTime()




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

	local t = ConstraintEditor.editedEnts
	if not t[ply] then t[ply] = {} end
	t[ply][ent] = ent

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

	local t = ConstraintEditor.editedEnts
	if not ( t[ply] and t[ply][ent] ) then return end
	t[ply][ent] = nil

	-- unsharedConstrs: constraints linked to ent but not to other entities in the selection
	local unsharedConstrs = ConstraintEditor.FindConstrsNotLinkedToEnts( ent, ConstraintEditor.GetEditedEntities( ply ) )

	ConstraintEditor.UnregisterConstrs( unsharedConstrs, ply )

	ConstraintEditor.FindAndSetProperToolStage( ply )

end


function ConstraintEditor.ToggleEditedEntity( ent, ply )

	local t = ConstraintEditor.editedEnts
	if t[ply] and t[ply][ent] then
		ConstraintEditor.UnregisterEditedEntity( ent, ply )
	else
		ConstraintEditor.RegisterEditedEntity( ent, ply )
	end

end



-- Clears the player edited entities, handles clientside consequences
function ConstraintEditor.UnregisterAllEditedEntities( ply )

	ConstraintEditor.editedEnts[ply] = nil

	ConstraintEditor.NetSend( NT.UNREGISTER_ALL_CONSTRS, ply )

	local tool = ConstraintEditor.GetTool( ply )
	if tool then tool:SetStage( 0 ) end

end


function ConstraintEditor.GetEditedEntities( ply )
	return ConstraintEditor.editedEnts[ply]
end


function ConstraintEditor.GetEditorPlayers()
	return table.GetKeys( ConstraintEditor.editedEnts )
end


-- Clears EditedEnts if player or entity is invalid
function ConstraintEditor.CleanupTables()

	ConstraintEditor.lastTablesCleanup = CurTime()

	for ply, entities in pairs( ConstraintEditor.editedEnts ) do
		if not IsValid( ply ) then
			ConstraintEditor.editedEnts[ply] = nil
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