function ConstraintEditor.IsConstrLinkedToEnts( constr, entities )
	for ent in pairs( entities or {} ) do
		if ent == constr.Ent1 or ent == ( constr.Ent2 or constr.Ent4 ) then
			return true
		end
	end
	return false
end


-- Returns all constraints of a specific type that are linked to at least one entity from the given entities table
-- TODO: move this function elsewhere?
function ConstraintEditor.FindConstrsInEnts( entities, constrType )

	local constrs = {}
	local found = {}

	for ent in pairs( entities or {} ) do

		local c = constrType and constraint.FindConstraints( ent, constrType ) or constraint.GetTable( ent )

		for _, constrTable in ipairs( c ) do
			local constr = constrTable.Constraint
			if constr and not found[constr] then
				table.insert( constrs, constrTable )
				found[constr] = true
			end
		end
	end
	return constrs
end