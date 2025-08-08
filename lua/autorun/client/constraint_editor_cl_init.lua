function ConstraintEditor.HandleNetRequests( mode )

	net.Receive( "constraint_editor_net", function( len, _ )

		local action	= net.ReadString()
		local data		= net.ReadTable()

		local cPanel		= controlpanel.Get( mode )
		local constrBrowser	= cPanel.constrBrowser
		if not IsValid( constrBrowser ) then return end

		if action == "set_surface_data" then

			constrBrowser:SetConstrs( data )

		elseif action == "set_constr_data" then

			PrintTable(data)
			constrBrowser:SetConstrData( data[1], data[2] )

		end

	end )

end


function ConstraintEditor.RequestConstrData( constrID )

	if not isnumber( constrID ) then return end
	net.Start( "constraint_editor_net" )
		net.WriteString( "get_constr_data" )
		net.WriteInt( constrID, 25 ) -- creation IDs go up to 10 million
	net.SendToServer()

end

-- Can recreate constraint
function ConstraintEditor.RequestSetConstrData( data )

	if not istable( data ) then return end

	net.Start( "constraint_editor_net" )
		net.WriteString( "set_constr_data" )
		net.WriteTable( data )
	net.SendToServer()

end