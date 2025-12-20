local PANEL = {}

local NT = ConstraintEditor.NetTags
local BIT_COUNT_CONSTR_ID	= ConstraintEditor.NetBitCounts.CONSTR_ID


function PANEL:Init()

	local editor = self

	self.constrArgsCache = {}
	self.constrDataCache = {}

	self.Divider = self:Add( "DVerticalDivider" )
	self.Divider:Dock( FILL )
	self.Divider:SetDividerHeight( 2 )


	self.Properties = self.Divider:Add( "DProperties" )
	self.Divider:SetTop( self.Properties )


	self.DividerList = self.Divider:Add( "DHorizontalDivider" )
	self.Divider:SetBottom( self.DividerList )
	self.DividerList:SetDividerWidth( 1 )

	self.ListButtons1 = self.DividerList:Add( "DListLayout" )
	self.DividerList:SetLeft( self.ListButtons1 )

		local ButtonApply = self.ListButtons1:Add( "DButton" )
		self.ButtonApply = ButtonApply
		ButtonApply:SetImage( "icon16/database_refresh.png" )
		ButtonApply:SetText( "Apply Changes" )

		function ButtonApply:DoClick()
			local constrID = editor.constrID
			local constrData = editor:GetConstrData()
			if constrID then
				ConstraintEditor.SendDataToServer( NT.UPDATE_CONSTR, { editor.constrID, BIT_COUNT_CONSTR_ID }, { constrData } )
			else
				ConstraintEditor.SendDataToServer( NT.UPDATE_TYPE,  { constrData.Type }, { constrData } )
			end
		end


		local ButtonDuplicate = self.ListButtons1:Add( "DButton" )
		self.ButtonDuplicate = ButtonDuplicate
		ButtonDuplicate:SetImage( "icon16/application_double.png" )
		ButtonDuplicate:SetText( "Duplicate Constraint" )

		function ButtonDuplicate:DoClick()
			ConstraintEditor.SendDataToServer( NT.DUPLIC_CONSTR, { editor.constrID, BIT_COUNT_CONSTR_ID } )
		end


		local ButtonDelete = self.ListButtons1:Add( "DButton" )
		self.ButtonDelete = ButtonDelete
		ButtonDelete:SetImage( "icon16/database_delete.png" )
		ButtonDelete:SetText( "Remove Constraint" )

		function ButtonDelete:DoClick()
			ConstraintEditor.SendDataToServer( NT.REMOVE_CONSTR, { editor.constrID, BIT_COUNT_CONSTR_ID } )
		end


	self.ListButtons2 = self.DividerList:Add( "DListLayout" )
	self.DividerList:SetRight( self.ListButtons2 )

		local ButtonCopy = self.ListButtons2:Add( "DButton" )
		self.ButtonCopy = ButtonCopy
		ButtonCopy:SetImage( "icon16/page_copy.png" )
		ButtonCopy:SetText( "Copy all values" )

		function ButtonCopy:DoClick()
			editor:CopyFullData()
			editor.ButtonPaste:SetEnabled( editor:CanPaste() )
		end

		local ButtonPaste = self.ListButtons2:Add( "DButton" )
		self.ButtonPaste = ButtonPaste
		ButtonPaste:SetImage( "icon16/page_paste.png" )
		ButtonPaste:SetText( "Paste all values" )

		function ButtonPaste:DoClick()
			editor:TryApplyData( editor.copiedConstrData )
		end

		ButtonPaste:SetEnabled( false )

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
	self.argsOrder = {}
	self.reverseArgs = {}

end


function PANEL:PerformLayout( width, height )

	local buttonHeightTotal = self.ButtonApply:GetTall() * 3
	self.Divider:SetBottomMin( buttonHeightTotal )
	self.Divider:SetTopMin( height - buttonHeightTotal )

	local leftWidth = width / 2

	self.DividerList:SetLeftMin( leftWidth )
	self.DividerList:SetRightMin( width - leftWidth )

	self.Divider:DoConstraints()

end

-- codedData is nearly the same as constrData but partly uses integer keys to conserve order
function PANEL:ShowConstr( codedData, args )

	self.Properties:Clear()
	self.constrData = {}
	self.constrDataCache = {}
	self.constrID = -1

	if not args then return end

	local constrID		= codedData.constrID
	local constrType	= codedData.Type
	self.constrID		= constrID
	self.constrData.Type	= constrType
	self.args		= args
	self.argsOrder	= {}
	self.rows		= {}

	local editor = self

	if self.ConstraintBrowser then
		if constrID then
			self.ConstraintBrowser:SelectConstrNode( constrID, constrType )
		else
			self.ConstraintBrowser:SelectTypeNode( constrType )
		end
	end

	for i, argName in ipairs( args ) do

		self.argsOrder[argName] = i

		local argValue			= codedData[i]
		local argType			= type( argValue )
		local cacheString
		if constrID then
			self.constrDataCache[i] = argValue
			cacheString		= tostring( argValue )
		end

		if argType == "table" and IsColor( argValue ) then
			argType = "color"
		end

		local typeRestore = self.typeRestoreFuncs[argType]

		local row		= self.Properties:CreateRow( "Constraint Properties", argName )
		self.rows[i]	= row
		row:Setup( argType == "boolean" and "Bool" or "Generic", { readonly = not typeRestore } )

		--local r, g, b, a = (row:GetSkin().Colours.Properties.Column_Selected or Color(255, 0, 0, 100)):Unpack()
		local r, g, b, a = 140, 220, 100, 100

		function row:DataChanged( v )
			self:SetValue( v )
		end

		function row:SetValue( v, isOriginal, doInner )

			if not isOriginal then v = typeRestore( v ) end
			stringV = tostring( v )
			if doInner then row.Inner:SetValue( stringV ) end
			local changed = cacheString ~= stringV
			self:SetBGColor( r, g, b, a )
			self:SetPaintBackgroundEnabled( changed )
			editor.constrData[i] = ( changed or nil ) and v

		end

		row:SetValue( argValue, true, true )

		if argType == "Entity" then

			-- TODO: change layout function for the row
			local buttonSwitch = row:Add( "DButton" )
				row.Button = buttonSwitch
				buttonSwitch:SetImage( "icon16/eye.png" )
				buttonSwitch:SetText( "Switch entity" )
				buttonSwitch:DockMargin(0, 1, 1, 1)
				buttonSwitch:Dock(RIGHT)
				local s = row:GetTall()
				buttonSwitch:SetSize( 2 * s, s )
				buttonSwitch:SetTooltip( "Switch this entity to the one you're looking at." )


				function buttonSwitch:DoClick()
					row:SetValue( LocalPlayer():GetEyeTrace().Entity, true, true )
				end

				local oldFunc = row.PerformLayout
				 function row:PerformLayout()
					oldFunc( self )
					self.Button:SetWide( self:GetWide() * 0.1 )
				end
		end
	end


	self.ButtonPaste:SetEnabled( self:CanPaste() )

	if constrType then

		local row = self.Properties:CreateRow( "Extra Information", "Type" )
		row:Setup( "String", { readonly = true } )
		row:SetValue( constrType )

	end

end


function PANEL:GetConstrData()

	return self.constrData

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

	--self.Properties:InvalidateChildren( true )

end


derma.DefineControl( "DConstraintEditor", "", PANEL, "DPanel" )