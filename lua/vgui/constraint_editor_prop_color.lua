
--
-- Modified from prop_vectorcolor
--

local function ColorToString( col )
	return math.floor( col.r ) .. " " .. math.floor( col.g ) .. " " .. math.floor( col.b ) .. " " .. math.floor( col.a )
end

DEFINE_BASECLASS( "DProperty_Generic" )

local PANEL = {}

function PANEL:Init()
end

--
-- Called by this control, or a derived control, to alert the row of the change
--
function PANEL:ValueChanged( newval, bForce )

	BaseClass.ValueChanged( self, newval, bForce )

	self.colorValue = string.ToColor( newval )

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
				-- sync the text with the actual color
				slf:SetText( ColorToString( self.colorValue ) )
				-- use this or the player has to click away (again) to get back their controls
				olf( slf )
			end
			break
		end
	end

	local btn = self:Add( "DButton" )
	btn:Dock( LEFT )
	btn:DockMargin( 0, 2, 4, 2 )
	btn:SetWide( 16 )
	btn:SetText( "" )

	btn.Paint = function( btn_slf, w, h )

		if self.colorValue then
			surface.SetDrawColor( self.colorValue:Unpack() )
			surface.DrawRect( 2, 2, w - 4, h - 4 )
		end

		surface.SetDrawColor( 0, 0, 0, 150 )
		surface.DrawOutlinedRect( 0, 0, w, h )

	end

	--
	-- Pop up a colour selector when we click on the button
	--
	btn.DoClick = function()

		local color = vgui.Create( "DColorCombo", self )

		color.Mixer:SetAlphaBar( true )
		color.Mixer:SetWangs( true )
		color.Mixer:SetLabel( "Choose a color for the constraint(s)." )
		color.Mixer.label:SetTextColor( Color( 255, 255, 255, 255 ) )
		color:SetupCloseButton( function() CloseDermaMenus() end )
		color.OnValueChanged = function( colorCombo, newcol )

			if not IsValid( self ) then return end

			local colorString = ColorToString( newcol )
			if IsValid( text ) then text:SetText( colorString ) end

			self:ValueChanged( colorString, true )

		end

		color:SetColor( self.colorValue )

		local menu = DermaMenu()
		menu:SetPaintBackground( false )
		menu:AddPanel( color )
		menu:Open( gui.MouseX() - color:GetWide() / 2, gui.MouseY() + 10 )


		-- Delete the popup if the edit window goes away
		btn.OnRemove = function()
			if IsValid( color ) then
				color:Remove()
			end
		end

	end

	local oldSetValue = self.SetValue
	-- Set the value
	function self:SetValue( val )

		if isstring( val ) then
			val = string.ToColor( val )
		end

		self.colorValue = val

		oldSetValue( self, ColorToString( val ) )
	end


end

-- Must start with "DProperty_" to stay compatible with DProperties
derma.DefineControl(
	"DProperty_constraint_editor_color",
	ConstraintEditor.dermaDesc or "",
	PANEL,
	"DProperty_Generic"
)