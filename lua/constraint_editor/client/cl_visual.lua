ConstraintEditor.dataPerConstrType = {
	Axis			= { icon = "icon16/cd.png", },
	-- AdvBallsocket	= { icon = "icon16/sport_shuttlecock.png", },
	AdvBallsocket	= { icon = "icon16/chart_pie.png", },
	-- AdvBallsocket	= { icon = "icon16/color_wheel.png", },
	Ballsocket		= { icon = "icon16/sport_golf.png", },
	Elastic			= { icon = "icon16/connect.png", },
	Hydraulic		= { icon = "icon16/joystick.png", },
	-- Hydraulic		= { icon = "icon16/newspaper.png", },
	Keepupright		= { icon = "icon16/arrow_up.png", },
	Motor			= { icon = "icon16/cd_burn.png", },
	Muscle			= { icon = "icon16/sport_football.png", },
	Pulley			= { icon = "icon16/vector.png", },
	Rope			= { icon = "icon16/link_break.png", },
	Slider			= { icon = "icon16/shape_align_center.png", },
	-- Slider			= { icon = "icon16/control_equalizer.png", },
	Weld			= { icon = "icon16/link.png", },
	Winch			= { icon = "icon16/webcam.png", },
	NoCollide		= { icon = "icon16/collision_off.png", },
}


	-- NoCollide is unlisted
--local constrTypes = { "Axis", "AdvBallsocket", "Ballsocket", "Elastic", "Hydraulic", "Keepupright", "Motor", "Muscle", "Pulley", "Rope", "Slider", "Weld", "Winch", "NoCollide", "Other" }
local constrTypes = { "Weld", "Keepupright", "Rope", "Muscle", "Hydraulic", "Winch", "Elastic", "Motor", "Axis", "Ballsocket", "AdvBallsocket", "Slider", "Other" }
local hueStep = 360 / #constrTypes

ConstraintEditor.dataPerConstrType.NoCollide.lineColor = HSVToColor( 0, 0, 0.5)

for i, constrType in ipairs( constrTypes ) do

	local data = ConstraintEditor.dataPerConstrType[constrType]
	if not data then
		data = { icon = "" }
		ConstraintEditor.dataPerConstrType[constrType] = data
	end

	local hue = ( - 0 + ( i - 1 ) * hueStep ) % 360
	data.lineColor	= HSVToColor( hue, 0.55, 0.95 )
	data.lineColor.a	= 180

	data.iconColor	= HSVToColor( hue, 0.5, 1 )
end