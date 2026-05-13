-- Gets the constraint editor tool of a player
-- Arguments:
--	ply (Player): The player whose constraint editor tool we want to get
-- Returns:
--	(table | nil): TOOL table of constraint editor, or nil if the table wasn't found or the player doesn't have a tool gun.
function ConstraintEditor.GetTool( ply )

	return ply:GetTool( ConstraintEditor.Mode )

end


-- Deletes a constraint entity and data associated to its constrID
--
-- Arguments:
--	constrs (table): Table whose values are the constraint entities we want to delete
function ConstraintEditor.DeleteConstrs( constrs )

	for _, constr in pairs( constrs ) do
		constr.CEInvalid = true
		SafeRemoveEntity( constr )
	end

	ConstraintEditor.UnregisterConstrs( constrs )

end