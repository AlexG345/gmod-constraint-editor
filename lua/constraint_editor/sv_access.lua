
----------------------------------------
-- Simplified safety checks           --
-- Replaces KnownConstr tables etc... --
----------------------------------------


function ConstraintEditor.AccessEntity( ply, ent )

	return ply and isentity( ent ) and ( ent:IsValid() or ( game.SinglePlayer() and ent:IsWorld() ) ) and hook.Run( "CanTool", ply, { Entity = ent }, ConstraintEditor.Mode, button ) and ent or false

end


function ConstraintEditor.AccessConstraint( ply, constr )

	local f = constr.GetConstrainedEntities
	local first, second = f and f( constr )
	return ( ConstraintEditor.AccessEntity( ply, first ) or ConstraintEditor.AccessEntity( ply, second ) ) and constr or false

end