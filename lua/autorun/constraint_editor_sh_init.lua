ConstraintEditor = {}

ConstraintEditor.NetTags = {
	SET_EDITED_ENTITY		= 0,
	UNSET_EDITED_ENTITY		= 1,
	LEFT_CLICK				= 2,
	RIGHT_CLICK				= 3,
	RELOAD					= 4,
	UPDATE_CONSTR			= 5,
	REMOVE_CONSTR			= 6,
	DUPLIC_CONSTR			= 7,
	SET_SHOWN_CONSTRS		= 8,
	ADD_SHOWN_CONSTRS		= 9,
	GET_MENU_DEEP_DATA		= 10,
	SET_MENU_DEEP_DATA		= 11,
	FORGET_CONSTR			= 12,
	TRANSFER_CONSTR_ENTS	= 13,
	TRANSFER_CONSTRS_ENTS	= 14,
}

ConstraintEditor.NetBitCounts = {
	TAG			= 4,
	CONSTR_ID	= 24, -- creation ids go up to 10 million
}