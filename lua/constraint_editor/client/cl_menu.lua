-- Gets the constraint browser vgui element from the main menu (tool control panel)
function ConstraintEditor.GetConstrBrowser()
	local cPanel = controlpanel.Get( ConstraintEditor.Mode )
	return cPanel and cPanel.constrBrowser
end