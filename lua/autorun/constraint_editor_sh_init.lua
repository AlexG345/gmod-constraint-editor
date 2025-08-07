ConstraintEditor = {}


-- try to get the descriptor of the constraint type represented by the argument
-- this actually doesn't do anything clientside since duplicator.ConstraintType is empty there
function ConstraintEditor.GetConstrDesc( a )

	local cType = isstring( a ) and a or ( istable( a ) or isentity( a ) ) and a.Type

	local desc = duplicator.ConstraintType[ cType ]

	if desc then return desc, cType end

end