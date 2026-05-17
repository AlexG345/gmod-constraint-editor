local NT = ConstraintEditor.netTags

function ConstraintEditor.StressTest()

	local ply = Entity( 1 )

	ConstraintEditor.UnregisterConstrIDs({})
	ConstraintEditor.UnregisterConstrIDs({[100] = true})


	local surfaceConstrsData = {}

	local constrID = 1
	for constrType, desc in pairs( duplicator.ConstraintType ) do
		local t = {}
		surfaceConstrsData[constrType] = t

		local n = 1
		for i = constrID, constrID + n - 1 do
			t[i] = {}
		end
		constrID = constrID + n
	end

	PrintTable( surfaceConstrsData )

	if ConstraintEditor.NetStartWrite( NT.REGISTER_CONSTRS, ply ) then
		net.WriteTable( surfaceConstrsData )
		net.Send( ply )
	end


	if ConstraintEditor.NetStartWrite( NT.FILL_CONSTR_EDITOR, ply ) then
		local constrData, desc = ConstraintEditor.GetConstrDataDefault( "AdvBallsocket", true )
		ConstraintEditor.NetWriteTable( { constrData, desc.Args } )
		net.Send( ply )
	end
end