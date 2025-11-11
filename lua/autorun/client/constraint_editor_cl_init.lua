local UPDATE_CONSTR = 0
local SET_MENU_SURFACE_DATA = 1
local SET_MENU_DEEP_DATA = 2
local GET_MENU_DEEP_DATA = 3
local REMOVE_MENU_CONSTR = 4
local ADD_MENU_SURFACE_DATA = 5

local REQ_BIT_COUNT = 3


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

		local request	= net.ReadUInt( REQ_BIT_COUNT )

		local cPanel		= controlpanel.Get( mode )
		local constrBrowser	= cPanel.constrBrowser
		if not IsValid( constrBrowser ) then return end

		if request == SET_MENU_SURFACE_DATA then

			constrBrowser:SetConstrs( net.ReadTable() )

		elseif request == SET_MENU_DEEP_DATA then

			local data = net.ReadTable()
			constrBrowser:ShowConstr( data[1], data[2] )

		elseif request == REMOVE_MENU_CONSTR then

			local constrID = net.ReadUInt( 24 )
			constrBrowser:RemoveConstr( constrID )

		elseif request == ADD_MENU_SURFACE_DATA then

			constrBrowser:AddConstrs( net.ReadTable() )

		end

	end )

end


function ConstraintEditor.RequestConstrData( constrID )

	if not isnumber( constrID ) then return end
	net.Start( "constraint_editor_net" )
		net.WriteUInt( GET_MENU_DEEP_DATA, REQ_BIT_COUNT )
		net.WriteUInt( constrID, 24 ) -- creation IDs go up to 10 million
	net.SendToServer()

end

-- Can recreate constraint (only if client has permission serverside)
function ConstraintEditor.RequestSetConstrData( data )

	if not istable( data ) then return end
	net.Start( "constraint_editor_net" )
		net.WriteUInt( UPDATE_CONSTR, REQ_BIT_COUNT )
		net.WriteTable( data )
	net.SendToServer()

end