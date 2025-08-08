local PANEL = {}

function PANEL:Init()

	self.constrArgsCache = {}

	self.Divider = self:Add( "DVerticalDivider" )
	self.Divider:Dock( FILL )
	self.Divider:SetDividerHeight( 2 )

	self.Properties = self.Divider:Add( "DProperties" )
	self.Divider:SetTop( self.Properties )

	self.DividerButtons = self.Divider:Add( "DHorizontalDivider" )
	self.Divider:SetBottom( self.DividerButtons )

	local ButtonApply = self.DividerButtons:Add( "DButton" )
	self.DividerButtons:SetLeft( ButtonApply )
	self.ButtonApply = ButtonApply
	ButtonApply:SetImage( "icon16/database_refresh.png" )
	ButtonApply:SetText( "Apply" )

	local ButtonDelete = self.DividerButtons:Add( "DButton" )
	self.DividerButtons:SetRight( ButtonDelete )
	self.ButtonDelete = ButtonDelete
	ButtonDelete:SetImage( "icon16/database_delete.png" )
	ButtonDelete:SetText( "Delete" )

	self.typeRestoreFuncs = {
		boolean	= tobool,
		number	= tonumber,
		string	= tostring,
		Vector	= Vector,
		table	= string.ToTable,
		color	= string.ToColor,
	}

end


function PANEL:PerformLayout( width, height )

	self.Divider:SetBottomMin( 20 )
	self.Divider:SetTopMin( height - 20 )
	self.Divider:DoConstraints()
	self.DividerButtons:SetLeftMin( width / 2 )
	self.DividerButtons:SetRightMin( width / 2 )

end

-- codedData is nearly the same as constrData but uses integer keys to conserve order
function PANEL:SetConstrData( codedData, args )

	self.Properties:Clear()
	self.constrData = {}

	if not args then return end

	self.constrData.Type		= codedData.Type
	self.constrData.constrID	= codedData.constrID

	for i, arg in ipairs( args ) do

		local row			= self.Properties:CreateRow( "Constraint Properties", arg )
		local argValue		= codedData[i]
		local argType		= type( argValue )
		local cacheString	= tostring( argValue )

		if argType == "table" and IsColor( argValue ) then
			argType = "color"
		end

		local typeRestore = self.typeRestoreFuncs[argType]

		row:Setup( argType == "boolean" and "Bool" or "Generic", { readonly = not typeRestore } )

		local editor = self
		function row:DataChanged( v )

			editor.constrData[i] = ( cacheString ~= v or nil ) and typeRestore( v )

		end

		row:SetValue( argValue )

	end

	if cType then

		local row = self.Properties:CreateRow( "Constraint Information", "Type" )
		row:Setup( "String", { readonly = true } )
		row:SetValue( constrType )

	end

end


function PANEL:GetConstrData()

	return self.constrData

end


function PANEL:GetButtonApply()

	return self.ButtonApply

end


derma.DefineControl( "DConstraintEditor", "", PANEL, "DPanel" )