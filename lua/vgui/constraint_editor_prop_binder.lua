DEFINE_BASECLASS( "DProperty_Generic" )

local PANEL = {}

function PANEL:Init()
end

--
-- Called by this control, or a derived control, to alert the row of the change
--
function PANEL:ValueChanged( stringNewVal, bForce )

	local newval = tonumber( stringNewVal )
	if newval == nil then
		newval = 0
		stringNewVal = "0"
	end

	BaseClass.ValueChanged( self, stringNewVal, bForce )

	self.bindValue = newval
	self.binder:SetValue( newval )

end

function PANEL:Setup( vars )

	vars = vars or {}

	BaseClass.Setup( self, vars )

	local text
	for _, panel in ipairs( self:GetChildren() ) do
		if panel:GetName() == "DTextEntry" then
			text = panel
			local olf = text.OnLoseFocus
			text.OnLoseFocus = function( slf )
				-- sync the text with the actual bind
				slf:SetText( tostring( self.bindValue ) )
				-- use this or the player has to click away (again) to get back their controls
				olf( slf )
			end
			break
		end
	end

	local binder = self:Add( "DBinder" )
	self.binder = binder
	binder:Dock( LEFT )

	binder.OnChange = function( _, bindValue )

		if not IsValid( self ) then return end

		local bindString = tostring( bindValue )
		if bindValue == self.bindValue then return end

		self:ValueChanged( bindString, true )

	end

	-- binder:SetValue( self.bindValue )


	local oldSetValue = self.SetValue
	-- Set the value
	function self:SetValue( val )

		val = val or 0
		if isstring( val ) then
			val = tonumber( val )
		end

		self.bindValue = val
		binder:SetValue( val )

		oldSetValue( self, tostring( val ) )
	end


end

-- Must start with "DProperty_" to stay compatible with DProperties
derma.DefineControl(
	"DProperty_constraint_editor_binder",
	ConstraintEditor.dermaDesc or "",
	PANEL,
	"DProperty_Generic"
)