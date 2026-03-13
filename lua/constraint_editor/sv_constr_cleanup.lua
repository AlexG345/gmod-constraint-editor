--------------------------------
--  Limits, cleanup, undo...  --
--------------------------------


-- You have to create the constraint first to know if it's a ropeconstraint or not
-- Note that ropeconstraints name come from the fact that they involve keyframe_rope entities
function ConstraintEditor.DoLimitsUndoCleanup( ply, constr, rope, enforceLimits, addUndo )

	if not ( constr or rope ) then return end

	local cleanupType = ConstraintEditor.GetCleanupType( constr, rope )

	if ply then

		if not game.SinglePlayer() and enforceLimits and ply:GetCount( cleanupType ) >= cvars.Number( "sbox_max" .. cleanupType, 0 ) then
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


function ConstraintEditor.GetCleanupType( constr, rope )
	if isentity( rope ) and rope:IsValid() then
		return "ropeconstraints"
	elseif isentity( constr ) and constr:IsValid() then
		return constr.Type == "NoCollide" and "nocollide" or "constraints"
	end
end