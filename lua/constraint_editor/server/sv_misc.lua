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

end


-- TODO: upgrade this?
-- This does not handle all cases, far from it
function ConstraintEditor.FindAndSetProperToolStage( ply )

	local tool = ConstraintEditor.GetTool( ply )
	if not tool then return end

	local playerData = ConstraintEditor.playersData[ply]
	if ( not playerData ) or next( playerData.editedEnts ) == nil then
		tool:SetStage( 0 )
	end

end