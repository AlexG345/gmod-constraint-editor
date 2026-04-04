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