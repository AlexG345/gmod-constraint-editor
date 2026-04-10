-- Checks if a constraint is linked to some specific entities
--
-- Arguments:
--	constr (table | Entity): the constraint table or entity we want to check
--	entities (table): table whose values should be the entities whose link with constr (arg) we want to check
--
-- Returns:
--	(boolean): true if constr (arg) is linked to at least one entity from entities (arg), false otherwise
function ConstraintEditor.IsConstrLinkedToEnts( constr, entities )
	local constrEnts = {
		[constr.Ent1] = true,
		[constr.Ent2 or constr.Ent4] = true
	}

	for _, ent in pairs( entities or {} ) do
		if constrEnts[ent] then return true end
	end

	return false
end


-- Finds all constraints (optionally of a certain type) linked to some specific entities
--
-- Arguments:
--	entities (table): table whose values should be the entities to which the constraints have to be linked to
--	consrType (string): the type of constraint to be matched (Rope, Weld, ...), use nil or false for no type restriction
--
-- Returns:
--	constrs (table): table containing all the constraint tables that are linked to at least one entity from entities (arg), and optionally whose type is constrType (arg).
function ConstraintEditor.FindConstrsLinkedToEnts( entities, constrType )

	local constrs = {}
	local found = {}

	for _, ent in pairs( entities or {} ) do

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


-- Finds all constraints linked to a specific entity but not to other specific entities
function ConstraintEditor.FindConstrsNotLinkedToEnts( ent, unwantedEnts )

	local c = constraint.GetTable( ent )

	if not unwantedEnts then return c end

	local constrs, unwanted = {}, {}

	for _, unwantedEnt in pairs( unwantedEnts ) do
		unwanted[unwantedEnt] = ( unwantedEnt ~= ent ) or nil
	end

	for _, constrTable in ipairs( c ) do

		if not ( unwanted[constrTable.Ent1] or unwanted[constrTable.Ent2 or constrTable.Ent4] ) then

			table.insert( constrs, constrTable )

		end
	end

	return constrs

end