local REMOVE_CONSTR			= 0
local UPDATE_CONSTR			= 1
local DUPLIC_CONSTR			= 2
local SET_MENU_SURFACE_DATA	= 3
local SET_MENU_DEEP_DATA	= 4
local GET_MENU_DEEP_DATA	= 5
local REMOVE_MENU_CONSTR	= 6
local ADD_MENU_SURFACE_DATA	= 7
local GET_ALL_CONSTRS		= 8

local BIT_COUNT_TAG			= 3
local BIT_COUNT_CONSTR_ID	= 24 -- creation ids go up to 10 million



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

		if tag == SET_MENU_SURFACE_DATA then

			constrBrowser:SetConstrs( net.ReadTable() )

		elseif tag == SET_MENU_DEEP_DATA then

			local data = net.ReadTable()
			constrBrowser:ShowConstr( data[1], data[2] )

		elseif tag == REMOVE_MENU_CONSTR then

			local constrID = net.ReadUInt( 24 )
			constrBrowser:RemoveConstr( constrID )

		elseif tag == ADD_MENU_SURFACE_DATA then

			constrBrowser:AddConstrs( net.ReadTable() )

		end

	end )

end


function ConstraintEditor.RequestConstrData( constrID )
	ConstraintEditor.SendDataToServer( GET_MENU_DEEP_DATA, constrID )
end


function ConstraintEditor.SendDataToServer( tag, constrID, data )

	if not isnumber( tag ) then return end

	net.Start( "constraint_editor_net" )
		net.WriteUInt( tag, BIT_COUNT_TAG )
		if isnumber( constrID ) then net.WriteUInt( constrID, BIT_COUNT_CONSTR_ID ) end
		if istable( data ) then net.WriteTable( data ) end
	net.SendToServer()

end