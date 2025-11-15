
local NT = ConstraintEditor.NetTags
local BIT_COUNT_TAG			= ConstraintEditor.NetBitCounts.TAG
local BIT_COUNT_CONSTR_ID	= ConstraintEditor.NetBitCounts.CONSTR_ID


ConstraintEditor.Constrs = {}
ConstraintEditor.HoveredConstrID = -1 -- for the stool


function ConstraintEditor.GetTestTable( constrID )
	return {
	[7]			=	500,
	[10]		=	100,
	[11]		=	"cable/cable",
	[12]		=	false,
	Type		=	"Rope",
	constrID	=	constrID
	}
end


function ConstraintEditor.HandleNetRequests( mode )

	net.Receive( "constraint_editor_net", function( len, _ )

		local tag	= net.ReadUInt( BIT_COUNT_TAG )

		local cPanel		= controlpanel.Get( mode )
		local constrBrowser	= cPanel.constrBrowser
		if not IsValid( constrBrowser ) then return end

		if tag == NT.LEFT_CLICK then

			local ent = net.ReadEntity()
			local hCID = ConstraintEditor.HoveredConstrID
			if not hCID or hCID == -1 then
				ConstraintEditor.SetEditedEntity( ent )
			else
				ConstraintEditor.RequestConstrData( hCID )
			end

		elseif tag == NT.SET_SHOWN_CONSTRS then

			local data = net.ReadTable() or {}
			constrBrowser:SetConstrs( data )
			ConstraintEditor.Constrs = data

		elseif tag == NT.SET_MENU_DEEP_DATA then

			local data = net.ReadTable()
			constrBrowser:ShowConstr( data[1], data[2] )

		elseif tag == NT.FORGET_CONSTR then

			local constrID = net.ReadUInt( 24 )
			constrBrowser:RemoveConstr( constrID )
			ConstraintEditor.ForgetConstr( constrID )

		elseif tag == NT.ADD_SHOWN_CONSTRS then

			local data = net.ReadTable()
			constrBrowser:AddConstrs( data )
			table.Merge( ConstraintEditor.Constrs, data )

		end

	end )

end


function ConstraintEditor.RequestConstrData( constrID )
	ConstraintEditor.SendDataToServer( NT.GET_MENU_DEEP_DATA, constrID )
end


function ConstraintEditor.SetEditedEntity( ent )
	ConstraintEditor.SendDataToServer( NT.SET_EDITED_ENTITY, nil, nil, ent )
end


function ConstraintEditor.ForgetConstr( constrID )
	for constrType, constrDatas in pairs( ConstraintEditor.Constrs ) do
		if constrDatas[constrID] then
			constrDatas[constrID] = nil
		end
	end
end


function ConstraintEditor.SendDataToServer( tag, constrID, data, ent )

	if not isnumber( tag ) then return end

	net.Start( "constraint_editor_net" )
		net.WriteUInt( tag, BIT_COUNT_TAG )
		if isnumber( constrID ) then net.WriteUInt( constrID, BIT_COUNT_CONSTR_ID ) end
		if istable( data ) then net.WriteTable( data ) end
		if isentity( ent ) then net.WriteEntity( ent ) end
	net.SendToServer()

end