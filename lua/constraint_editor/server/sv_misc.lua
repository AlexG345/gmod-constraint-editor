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




--[[ TODO: go back to this and fix
hook.Add( "EntityRemoved", "Constraint Library - ConstraintRemoved", function( ent )

	-- Remove this constraint from Entity.Constraints table of the constrained entities
	if ( ent:IsConstraint() || constraintClasses[ ent:GetClass() ] ) then

-- TODO: reread this it's just experimental for now!! it's probably bad practice to overwrite a hook like that too
-- lua_run print( hook.GetTable().EntityRemoved["Constraint Library - ConstraintRemoved"])
-- https://github.com/Facepunch/garrysmod/blob/b2bff902adf7f5b87ec543f873e74e3267e93f26/garrysmod/lua/includes/modules/constraint.lua#L30
local oldHook = hook.GetTable().EntityRemoved["Constraint Library - ConstraintRemoved"]
hook.Add( "EntityRemoved", "Constraint Library - ConstraintRemoved", function( ent )
	print("a")
end )
]]