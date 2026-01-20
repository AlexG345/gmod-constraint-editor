
-- Returns the descriptor (desc) of the constraint type represented by the argument (constrType), as well as the constraint type
-- desc will be in this format: { Args = (sequential table of argument names for the duplicator function), Func = (duplicator function used to create constraint)}
-- constrType is a string (e.g. "Rope", "Weld", ...)
function ConstraintEditor.GetConstrDescriptor( thing )

	local constrType = isstring( thing ) and thing or ( istable( thing ) or isentity( thing ) ) and thing.Type
	local desc = duplicator.ConstraintType[constrType]
	if desc then return desc, constrType end

end


function ConstraintEditor.GetConstrData( thing )