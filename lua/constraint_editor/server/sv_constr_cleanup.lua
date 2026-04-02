--------------------------------
--  Limits, cleanup, undo...  --
--------------------------------


-- Optionally checks sandbox limits before adding a constraint as a sandbox cleanup entry, optionally as an undo entry, for a player.
-- If sandbox limits are checked, and found to have been hit, then the constraint is deleted.
--
-- Arguments:
--	ply (Player): The player who supposedly owns the constraint
--	constr (Entity | nil): The constraint entity used as cleanup entry etc
--	rope (Entity (keyframe_rope) | nil): The visual part of the constraint
--	enforceLimits (boolean): Only if true, sandbox limits are checked, which can result in the deletion of the constraint and rope.
--	addUndo (boolean): Only if true, an entry is added to the undo menu for ply (arg).
--
-- Returns:
--	(boolean): false if a sandbox limit was hit, true otherwise
--
-- TODO: fix this:
--	You have to create the constraint first to know if it's a ropeconstraint or not
--	Note that ropeconstraints name come from the fact that they involve keyframe_rope entities
function ConstraintEditor.DoLimitsUndoCleanup( ply, constr, rope, enforceLimits, addUndo )

	if not ( constr or rope ) then return end

	local cleanupType = ConstraintEditor.GetCleanupType( constr, rope )

	if ply then

		if enforceLimits and not game.SinglePlayer() and ply:GetCount( cleanupType ) >= cvars.Number( "sbox_max" .. cleanupType, 0 ) then
			ply:LimitHit( cleanupType )
			SafeRemoveEntity( constr )
			SafeRemoveEntity( rope )
			return false
		end

		if addUndo then
			undo.Create( constr.Type )
				undo.SetPlayer( ply )
				undo.AddEntity( constr or rope )
			undo.Finish()
		end

		ply:AddCount( cleanupType, constr or rope )
	end

	-- does this work if ply is nil?
	cleanup.Add( ply, cleanupType, constr or rope )

	return true

end

-- Gets the cleanup type of an existing valid constraint
--
-- Arguments:
--	constr (Entity | nil): The constraint entity whose cleanup type we want
--	rope (Entity (keyframe_rope) | nil): The visual part of the constraint
--
-- Returns:
--	(string | nil): The cleanup type of constr (arg), nil or "nocollide" or "constraints" or "ropeconstraints"
function ConstraintEditor.GetCleanupType( constr, rope )
	-- TODO: check if this detect Ropes, etc whose color has alpha = 0
	if isentity( rope ) and rope:IsValid() then
		return "ropeconstraints"
	elseif isentity( constr ) and constr:IsValid() then
		return constr.Type == "NoCollide" and "nocollide" or "constraints"
	end
end