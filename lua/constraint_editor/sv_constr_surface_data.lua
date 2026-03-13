---------------------------------------
--  Surface Constraint Data Getters  --
---------------------------------------


-- First returned table contains basic info (for clientside HUD) of the entity's valid constraints.
-- Second returned table's keys are creation IDs, values are constraint entities
function ConstraintEditor.GetEntSurfaceConstrsData( ent )

	if not ( isentity( ent ) and ( ent:IsValid() or ent:IsWorld() ) ) then return false end

	local surfaceConstrsData = {}
	local constrs = {}
	local constrTable = constraint.GetTable( ent )

	for _, constrData in ipairs( constrTable ) do

		local constr = constrData.Constraint or NULL

		local surfaceConstrData, constrType, constrID = ConstraintEditor.GetSurfaceConstrData( constr )
		if constrID then
			surfaceConstrsData[constrType] = surfaceConstrsData[constrType] or {}
			surfaceConstrsData[constrType][constrID] = surfaceConstrData[constrType][constrID]
			constrs[constrID] = constr
		end
	end

	return surfaceConstrsData, constrs

end


-- Returns a table containing basic constraint information (used for HUD clientside)
function ConstraintEditor.GetSurfaceConstrData( constr )

	if not constr then return end

	local constrType	= constr.Type
	local constrID		= constr.GetCreationID and constr:GetCreationID()

	if constr.CEInvalid or not ( constr:IsValid() and constrType and constrID ) then return end

	return {
		[constrType] = {
			[constrID] = {
				constr.Ent1, constr.Ent2 or constr.Ent4, constr.LPos1, constr.LPos2 or constr.LPos4 or constr.LPos, constr.WPos2, constr.WPos3, constr.LocalAxis
			}
		}
	}, constrType, constrID

end