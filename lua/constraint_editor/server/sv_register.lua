local NT				= ConstraintEditor.netTags
local TABLES_CLEANUP_CD	= 30 -- cooldown for table cleanup


-- Keys are constraint creation IDs, values are the associated constraint entities
ConstraintEditor.constrs = {}

-- Keys are players, values are entities (props)
ConstraintEditor.editedEnts = {}

-- Time since the last table cleanup
ConstraintEditor.lastTablesCleanup = CurTime()

-- Filter containing the players that might be editing a constraint
ConstraintEditor.editingPlayers = RecipientFilter()




---------------------
--  aaaaaaaaaaaaa  --
---------------------


-- Stores constraints by their creation IDs so that they can then be quickly accessed
--
-- Argument:
--	constrs (table): Table with keys constraint creation IDs and values the associated constraints
function ConstraintEditor.RegisterConstrs( constrs )
	table.Merge( ConstraintEditor.constrs, constrs, true )
end


-- Forgets all data related to some constraints using their creation IDs
function ConstraintEditor.UnregisterConstrs( constrIDs )

	ConstraintEditor.NetBroadcast(
		NT.UNREGISTER_CONSTRS,
		ConstraintEditor.ToNetConstrIDs( constrIDs )
	)

	for constrID, _ in pairs( constrIDs ) do
		ConstraintEditor.constrs[constrID] = nil
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


-- Tries to let the player edit of the constraints that are linked to the entity
function ConstraintEditor.RegisterEditedEntity( ent, ply )

	if not ConstraintEditor.AccessEntity( ply, ent, 1 ) then return end

	local t = ConstraintEditor.editedEnts
	if not t[ply] then t[ply] = {} end
	t[ply][ent] = ent

	local surfaceConstrsData, constrs = ConstraintEditor.GetEntSurfaceConstrsData( ent )

	ConstraintEditor.RegisterConstrs( constrs )

	ConstraintEditor.NetSend(
		NT.REGISTER_CONSTRS, ply,
		{ surfaceConstrsData }
	)

	local tool = ConstraintEditor.GetTool( ply )
	if tool then tool:SetStage( 1 ) end

end


function ConstraintEditor.UnregisterEditedEntity( ent, ply )

	local t = ConstraintEditor.editedEnts
	if not ( t[ply] and t[ply][ent] ) then return end
	t[ply][ent] = nil

	local c = ConstraintEditor.FindConstrsNotLinkedToEnts( ent, ConstraintEditor.GetEditedEntities( ply ) )

	local surfaceConstrsData, constrs = ConstraintEditor.GetSurfaceConstrsData( c )

	ConstraintEditor.UnregisterConstrs( constrs )

	ConstraintEditor.NetSend(
		NT.UNREGISTER_CONSTRS, ply,
		ConstraintEditor.ToNetConstrIDs( surfaceConstrsData )
	)

	if next( t[ply] ) == nil then
		local tool = ConstraintEditor.GetTool( ply )
		if tool then tool:SetStage( 0 ) end
	end

end


-- Clears the player edited entities, handles clientside consequences
function ConstraintEditor.UnregisterAllEditedEntities( ply )

	ConstraintEditor.editedEnts[ply] = nil

	ConstraintEditor.NetSend(
		NT.UNREGISTER_ALL_CONSTRS, ply
	)

	local tool = ConstraintEditor.GetTool( ply )
	if tool then tool:SetStage( 0 ) end

end


function ConstraintEditor.GetEditedEntities( ply )
	return ConstraintEditor.editedEnts[ply]
end


-- Forgets constrIDs:
--		that have no related data
-- 		whose associated constraint is not valid (e.g. has been removed)
-- 		that have no player permissions
-- Also clears EditedEnts if player or entity is invalid
function ConstraintEditor.CleanupTables()

	ConstraintEditor.lastTablesCleanup = CurTime()

	-- TODO: check if this is useful or not (do recipient filters automatically remove invalid players?)
	local online = RecipientFilter()
	online:AddAllPlayers()
	ConstraintEditor.editingPlayers:RemoveMismatchedPlayers( online )


	local badConstrIDs = {}

	for constrID, ent in pairs( ConstraintEditor.constrs ) do
		if not IsValid( ent ) then
			badConstrIDs[constrID] = true
		end
	end

	if next( badConstrIDs ) ~= nil then
		ConstraintEditor.UnregisterConstrs( badConstrIDs )
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
	print( "deleting: ", constr, "[", constrID, "]")
	ConstraintEditor.UnregisterConstrs( { [constrID] = true } )
	SafeRemoveEntity( constr )
end