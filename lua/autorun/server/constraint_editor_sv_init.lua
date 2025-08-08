util.AddNetworkString( "constraint_editor_net" )

-- This is bad: since its shared by all players, it could easily lead to client abuse (modification of other people's constraints)
ConstraintEditor.constrs = {}


-- First returned table containins lists of creation IDs of ent's valid constraints.
-- The keys used to access those lists are constraint types.
-- Second returned table's keys are creation IDs, values are constraint entities
function ConstraintEditor.GetSurfaceConstrData( ent )

	if not ( isentity( ent ) and ( ent:IsValid() or ent:IsWorld() ) ) then return false end

	local surfaceConstrData = {}
	local constrs = {}
	local constrTable = constraint.GetTable( ent )

	for _, constrData in ipairs( constrTable ) do

		local constrType	= constrData.Type
		local constr		= constrData.Constraint or NULL
		local constrID		= constr.GetCreationID and constr:GetCreationID()

		if constr:IsValid() and constrType and constrID then
			constrs[constrID] = constr
			surfaceConstrData[constrType] = surfaceConstrData[constrType] or {}
			table.insert( surfaceConstrData[constrType], constrID )
		end

	end

	return surfaceConstrData, constrs

end


function ConstraintEditor.GetConstrData( a, coded )

	local desc, cType = ConstraintEditor.GetConstrDesc( a )

	if not desc then return end

	local data	= {}

	local args = desc.Args
	for i, arg in ipairs( args ) do
		data[coded and i or arg] = a[arg]
	end

	if next( data ) == nil then return end

	data.constrID = a.constrID or a.GetCreationID and a:GetCreationID()
	data.Type = cType

	return data, desc

end



function ConstraintEditor.DecodeConstrData( data )

	local desc = ConstraintEditor.GetConstrDesc( data )

	if not desc then return end

	for i, arg in ipairs( desc.Args ) do
		data[arg] = data[i] or data[arg]
		data[i]	  = nil
	end

	return data

end


function ConstraintEditor.SetConstrData( constr, newData, ply )

	local data, desc = ConstraintEditor.GetConstrData( constr, true )
	if not ( data and desc ) then return end

	local updateNeeded	= false

	for i, arg in ipairs( desc.Args ) do

		if newData[i] == nil then newData[i] = data[i] end

		updateNeeded = updateNeeded or newData[i] ~= data[i]

	end

	if not updateNeeded then return end

	--SetPhysConstraintSystem( ent.constraintSystem )

	local newConstr = desc.Func( unpack( newData ) )
	if not newConstr and newConstr:IsValid() then return false end

	undo.ReplaceEntity( constr, newConstr)
	cleanup.ReplaceEntity( constr, newConstr )

	local constrID, newConstrID = constr:GetCreationID(), newConstr:GetCreationID()
	if ConstraintEditor.constrs[constrID] then
		ConstraintEditor.constrs[constrID] = nil
		ConstraintEditor.constrs[newConstrID] = newConstr
	end

	SafeRemoveEntity( constr )

	if ply then ConstraintEditor.SetEditedConstr( newConstr, ply ) end

	--SetPhysConstraintSystem( NULL )

end


function ConstraintEditor.SendDataToClient( action, data, ply )

	if not isstring( action ) then return end
	if not isentity( ply ) and ply:IsPlayer() then return end
	if not istable( data ) then data = {} end

	net.Start( "constraint_editor_net" )
		net.WriteString( action )
		net.WriteTable( data )
	net.Send( ply )

end



function ConstraintEditor.SetEditedEntity( ent, ply )

	local surfaceConstrData, constrs = ConstraintEditor.GetSurfaceConstrData( ent )
	ConstraintEditor.constrs = constrs
	ConstraintEditor.SendDataToClient( "set_surface_data", surfaceConstrData, ply )

end


function ConstraintEditor.SetEditedConstr( constr, ply )

	local constrData, desc = ConstraintEditor.GetConstrData( constr, true )
	if not ( constrData and desc ) then return end
	ConstraintEditor.SendDataToClient( "set_constr_data", { constrData, desc.Args }, ply )

end


function ConstraintEditor.HandleNetRequests()

	net.Receive( "constraint_editor_net", function( len, ply )

		local request = net.ReadString()

		if request == "get_constr_data" then

			local constrID = net.ReadInt( 25 )
			local constr = ConstraintEditor.constrs[constrID]

			ConstraintEditor.SetEditedConstr( constr, ply )

		elseif request == "set_constr_data" then

			local newData = net.ReadTable()

			local constrID	= newData.constrID
			if not constrID then return end

			local constr	= ConstraintEditor.constrs[ constrID ]

			ConstraintEditor.SetConstrData( constr, newData, ply )

		end

	end )

end