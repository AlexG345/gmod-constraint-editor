local PANEL = {}

function PANEL:Init()

	local editor = self

	self.constrArgsCache = {}
	self.constrDataCache = {}

	self.Divider = self:Add( "DVerticalDivider" )
	self.Divider:Dock( FILL )
	self.Divider:SetDividerHeight( 2 )


	self.Properties = self.Divider:Add( "DProperties" )
	self.Divider:SetTop( self.Properties )


	self.DividerButtons = self.Divider:Add( "DVerticalDivider" )
	self.Divider:SetBottom( self.DividerButtons )
	self.DividerButtons:SetDividerHeight( 1 )


	self.DividerButtons1 = self.DividerButtons:Add( "DHorizontalDivider" )
	self.DividerButtons1:SetDividerWidth( 1 )
	self.DividerButtons:SetTop( self.DividerButtons1 )

		local ButtonCopy = self.DividerButtons1:Add( "DButton" )
		self.DividerButtons1:SetLeft( ButtonCopy )
		self.ButtonCopy = ButtonCopy
		ButtonCopy:SetImage( "icon16/page_copy.png" )
		ButtonCopy:SetText( "Copy all values" )

		function ButtonCopy:DoClick()
			editor:CopyFullData()
			editor.ButtonPaste:SetEnabled( editor:CanPaste() )
		end

		local ButtonPaste = self.DividerButtons1:Add( "DButton" )
		self.DividerButtons1:SetRight( ButtonPaste )
		self.ButtonPaste = ButtonPaste
		ButtonPaste:SetImage( "icon16/page_paste.png" )
		ButtonPaste:SetText( "Paste all values" )

		function ButtonPaste:DoClick()
			editor:TryApplyData( editor.copiedConstrData )
		end

		ButtonPaste:SetEnabled( false )


	self.DividerButtons2 = self.DividerButtons:Add( "DHorizontalDivider" )
	self.DividerButtons2:SetDividerWidth( 1 )
	self.DividerButtons:SetBottom( self.DividerButtons2 )

		local ButtonApply = self.DividerButtons2:Add( "DButton" )
		self.DividerButtons2:SetLeft( ButtonApply )
		self.ButtonApply = ButtonApply
		ButtonApply:SetImage( "icon16/database_refresh.png" )
		ButtonApply:SetText( "Apply Changes" )

		local ButtonDelete = self.DividerButtons2:Add( "DButton" )
		self.DividerButtons2:SetRight( ButtonDelete )
		self.ButtonDelete = ButtonDelete
		ButtonDelete:SetImage( "icon16/database_delete.png" )
		ButtonDelete:SetText( "Delete Constraint" )


	self.typeRestoreFuncs = {
		boolean	= tobool,
		number	= tonumber,
		string	= tostring,
		Vector	= Vector,
		table	= string.ToTable,
		color	= string.ToColor,
	}

	self.constrData			= {}
	self.constrDataCache	= {}
	self.copiedConstrData	= {}

	self.rows = {}
	self.args = {}

end


function PANEL:PerformLayout( width, height )

	local buttonHeightTotal = 50
	self.Divider:SetBottomMin( buttonHeightTotal )
	self.Divider:SetTopMin( height - buttonHeightTotal )

	self.DividerButtons:SetBottomMin( buttonHeightTotal / 2 )
	self.DividerButtons:SetTopMin( buttonHeightTotal / 2 )

	self.Divider:DoConstraints()
	self.DividerButtons1:SetLeftMin( width / 2 )
	self.DividerButtons1:SetRightMin( width / 2 )
	self.DividerButtons2:SetLeftMin( width / 2 )
	self.DividerButtons2:SetRightMin( width / 2 )

end

-- codedData is nearly the same as constrData but partly uses integer keys to conserve order
function PANEL:ShowConstr( codedData, args )

	self.Properties:Clear()
	self.constrData = {}
	self.constrDataCache = {}

	if not args then return end

	local constrID		= codedData.constrID
	local constrType	= codedData.Type
	self.constrData.constrID	= constrID
	self.constrData.Type		= constrType
	self.args	= args
	self.rows	= {}

	local editor = self

	if self.ConstraintBrowser then self.ConstraintBrowser:SelectConstrNode( constrID, constrType ) end

	for i, argName in ipairs( args ) do

		local row		= self.Properties:CreateRow( "Constraint Properties", argName )
		self.rows[i]	= row

		local argValue			= codedData[i]
		self.constrDataCache[i] = argValue
		local argType			= type( argValue )
		local cacheString		= tostring( argValue )

		if argType == "table" and IsColor( argValue ) then
			argType = "color"
		end

		local typeRestore = self.typeRestoreFuncs[argType]

		row:Setup( argType == "boolean" and "Bool" or "Generic", { readonly = not typeRestore } )

		function row:DataChanged( v )

			editor.constrData[i] = ( cacheString ~= v or nil ) and typeRestore( v )

		end

		row:SetValue( argValue )

	end

	self.ButtonPaste:SetEnabled( self:CanPaste() )

	--[[
	if constrType then

		local row = self.Properties:CreateRow( "Constraint Information", "Type" )
		row:Setup( "String", { readonly = true } )
		row:SetValue( constrType )

	end
	]]

end


function PANEL:GetConstrData()

	return self.constrData

end


function PANEL:GetButtonApply()

	return self.ButtonApply

end


function PANEL:GetButtonDelete()

	return self.ButtonDelete

end


function PANEL:CanPaste()

	return self.constrData and self.constrData.Type and self.constrData.Type == self.copiedConstrData.Type

end




function PANEL:CopyFullData()

	if not ( self.constrDataCache and self.constrData ) then return end

	table.CopyFromTo( self.constrDataCache, self.copiedConstrData )
	table.Merge( self.copiedConstrData, self.constrData )

end


-- tries to apply new data upon existing rows
function PANEL:TryApplyData( constrData )

	if not ( constrData and self.constrData ) then return end

	if constrData.Type ~= self.constrData.Type then return end

	for k, v in pairs( constrData ) do

		local row = self.rows[k]
		if IsValid( row ) and row:IsEnabled() then

			-- Doesn't work most of the time? Might have something to do with CacheValue.
			-- https://github.com/Facepunch/garrysmod/blob/11b0c919d7fa57c2b32a82e27e5362ae3357ce7d/garrysmod/lua/vgui/dproperties.lua#L77
			row:SetValue( v )
			-- fix:
			row.Inner:SetValue( v )

			if self.constrDataCache[k] == v then v = nil end

			self.constrData[k] = v
		end

	end

	self.Properties:InvalidateChildren( true )

end


derma.DefineControl( "DConstraintEditor", "", PANEL, "DPanel" )