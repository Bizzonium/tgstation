/obj/item/mod/core
	name = "MOD core"
	desc = "A non-functional MOD core. Inform the admins if you see this."
	icon = 'icons/obj/clothing/modsuit/mod_construction.dmi'
	icon_state = "mod-core"
	inhand_icon_state = "electronic"
	lefthand_file = 'icons/mob/inhands/misc/devices_lefthand.dmi'
	righthand_file = 'icons/mob/inhands/misc/devices_righthand.dmi'
	/// MOD unit we are powering.
	var/obj/item/mod/control/mod

/obj/item/mod/core/Destroy()
	if(mod)
		uninstall()
	return ..()

/obj/item/mod/core/proc/install(obj/item/mod/control/mod_unit)
	mod = mod_unit
	mod.core = src
	forceMove(mod)

/obj/item/mod/core/proc/uninstall()
	mod.core = null
	mod = null

/obj/item/mod/core/proc/charge_source()
	return

/obj/item/mod/core/proc/charge_amount()
	return 0

/obj/item/mod/core/proc/max_charge_amount()
	return 1

/obj/item/mod/core/proc/add_charge(amount)
	return FALSE

/obj/item/mod/core/proc/subtract_charge(amount)
	return FALSE

/obj/item/mod/core/proc/update_charge_alert()
	mod.wearer.clear_alert("mod_charge")

/obj/item/mod/core/standard
	name = "MOD standard core"
	icon_state = "mod-core-standard"
	desc = "Growing in the most lush, fertile areas of the planet Sprout, there is a crystal known as the Heartbloom. \
		These rare, organic piezoelectric crystals are of incredible cultural significance to the artist castes of the \
		Ethereals, owing to their appearance; which is exactly similar to that of an Ethereal's heart.\n\
		Which one you have in your suit is unclear, but either way, \
		it's been repurposed to be an internal power source for a Modular Outerwear Device."
	/// Installed cell.
	var/obj/item/stock_parts/cell/cell

/obj/item/mod/core/standard/Destroy()
	if(cell)
		QDEL_NULL(cell)
	return ..()

/obj/item/mod/core/standard/install(obj/item/mod/control/mod_unit)
	. = ..()
	if(cell)
		install_cell(cell)
	RegisterSignal(mod, COMSIG_PARENT_EXAMINE, .proc/on_examine)
	RegisterSignal(mod, COMSIG_ATOM_ATTACK_HAND, .proc/on_attack_hand)
	RegisterSignal(mod, COMSIG_PARENT_ATTACKBY, .proc/on_attackby)

/obj/item/mod/core/standard/uninstall()
	if(!QDELETED(cell))
		cell.forceMove(drop_location())
	uninstall_cell()
	UnregisterSignal(mod, list(COMSIG_PARENT_EXAMINE, COMSIG_ATOM_ATTACK_HAND, COMSIG_PARENT_ATTACKBY))
	return ..()

/obj/item/mod/core/standard/charge_source()
	return cell

/obj/item/mod/core/standard/charge_amount()
	var/obj/item/stock_parts/cell/charge_source = charge_source()
	return charge_source?.charge || 0

/obj/item/mod/core/standard/max_charge_amount(amount)
	var/obj/item/stock_parts/cell/charge_source = charge_source()
	return charge_source?.maxcharge || 1

/obj/item/mod/core/standard/add_charge(amount)
	var/obj/item/stock_parts/cell/charge_source = charge_source()
	if(!charge_source)
		return FALSE
	return charge_source.give(amount)

/obj/item/mod/core/standard/subtract_charge(amount)
	var/obj/item/stock_parts/cell/charge_source = charge_source()
	if(!charge_source)
		return FALSE
	return charge_source.use(amount)

/obj/item/mod/core/standard/update_charge_alert()
	var/obj/item/stock_parts/cell/charge_source = charge_source()
	if(!charge_source)
		mod.wearer.throw_alert("mod_charge", /atom/movable/screen/alert/nocell)
		return
	var/remaining_cell = charge_amount() / max_charge_amount()
	switch(remaining_cell)
		if(0.75 to INFINITY)
			mod.wearer.clear_alert("mod_charge")
		if(0.5 to 0.75)
			mod.wearer.throw_alert("mod_charge", /atom/movable/screen/alert/lowcell, 1)
		if(0.25 to 0.5)
			mod.wearer.throw_alert("mod_charge", /atom/movable/screen/alert/lowcell, 2)
		if(0.01 to 0.25)
			mod.wearer.throw_alert("mod_charge", /atom/movable/screen/alert/lowcell, 3)
		else
			mod.wearer.throw_alert("mod_charge", /atom/movable/screen/alert/emptycell)

/obj/item/mod/core/standard/proc/install_cell(new_cell)
	cell = new_cell
	cell.forceMove(src)
	RegisterSignal(src, COMSIG_ATOM_EXITED, .proc/on_exit)

/obj/item/mod/core/standard/proc/uninstall_cell()
	if(!cell)
		return
	cell = null
	UnregisterSignal(src, COMSIG_ATOM_EXITED)

/obj/item/mod/core/standard/proc/on_exit(datum/source, obj/item/stock_parts/cell, direction)
	SIGNAL_HANDLER

	if(!istype(cell) || cell.loc == src)
		return
	uninstall_cell()

/obj/item/mod/core/standard/proc/on_examine(datum/source, mob/examiner, list/examine_text)
	SIGNAL_HANDLER

	if(!mod.open)
		return
	examine_text += cell ? "You could remove the cell with an empty hand." : "You could use a cell on it to install one."

/obj/item/mod/core/standard/proc/on_attack_hand(datum/source, mob/living/user)
	SIGNAL_HANDLER

	if(mod.seconds_electrified && charge_amount() && mod.shock(user))
		return COMPONENT_CANCEL_ATTACK_CHAIN
	if(mod.open && mod.loc == user)
		INVOKE_ASYNC(src, .proc/mod_uninstall_cell, user)
		return COMPONENT_CANCEL_ATTACK_CHAIN
	return NONE

/obj/item/mod/core/standard/proc/mod_uninstall_cell(mob/living/user)
	if(!cell)
		mod.balloon_alert(user, "no cell!")
		return
	mod.balloon_alert(user, "removing cell...")
	if(!do_after(user, 1.5 SECONDS, target = mod))
		mod.balloon_alert(user, "interrupted!")
		return
	mod.balloon_alert(user, "cell removed")
	playsound(mod, 'sound/machines/click.ogg', 50, TRUE, SILENCED_SOUND_EXTRARANGE)
	uninstall_cell()
	cell.forceMove(drop_location())
	user.put_in_hands(cell)
	mod.update_charge_alert()

/obj/item/mod/core/standard/proc/on_attackby(datum/source, obj/item/attacking_item, mob/user)
	SIGNAL_HANDLER

	if(istype(attacking_item, /obj/item/stock_parts/cell))
		if(!mod.open)
			mod.balloon_alert(user, "open the cover first!")
			playsound(mod, 'sound/machines/scanbuzz.ogg', 25, TRUE, SILENCED_SOUND_EXTRARANGE)
			return NONE
		if(cell)
			mod.balloon_alert(user, "cell already installed!")
			playsound(mod, 'sound/machines/scanbuzz.ogg', 25, TRUE, SILENCED_SOUND_EXTRARANGE)
			return COMPONENT_NO_AFTERATTACK
		install_cell(attacking_item)
		mod.balloon_alert(user, "cell installed")
		playsound(mod, 'sound/machines/click.ogg', 50, TRUE, SILENCED_SOUND_EXTRARANGE)
		mod.update_charge_alert()
		return COMPONENT_NO_AFTERATTACK
	return NONE

/obj/item/mod/core/ethereal
	name = "MOD ethereal core"
	icon_state = "mod-core-ethereal"
	desc = "A reverse engineered core of a Modular Outerwear Device. Using natural liquid electricity from Ethereals, \
		preventing the need to use external sources to convert electric charge."
	/// A modifier to all charge we use, ethereals don't need to spend as much energy as normal suits.
	var/charge_modifier = 0.1

/obj/item/mod/core/ethereal/charge_source()
	var/obj/item/organ/stomach/ethereal/ethereal_stomach = mod.wearer.getorganslot(ORGAN_SLOT_STOMACH)
	if(!istype(ethereal_stomach))
		return
	return ethereal_stomach

/obj/item/mod/core/ethereal/charge_amount()
	var/obj/item/organ/stomach/ethereal/charge_source = charge_source()
	return charge_source?.crystal_charge || ETHEREAL_CHARGE_NONE

/obj/item/mod/core/ethereal/max_charge_amount()
	return ETHEREAL_CHARGE_FULL

/obj/item/mod/core/ethereal/add_charge(amount)
	var/obj/item/organ/stomach/ethereal/charge_source = charge_source()
	if(!charge_source)
		return FALSE
	charge_source.adjust_charge(amount*charge_modifier)
	return TRUE

/obj/item/mod/core/ethereal/subtract_charge(amount)
	var/obj/item/organ/stomach/ethereal/charge_source = charge_source()
	if(!charge_source)
		return FALSE
	charge_source.adjust_charge(-amount*charge_modifier)
	return TRUE

/obj/item/mod/core/ethereal/update_charge_alert()
	var/obj/item/organ/stomach/ethereal/charge_source = charge_source()
	if(charge_source)
		mod.wearer.clear_alert("mod_charge")
		return
	mod.wearer.throw_alert("mod_charge", /atom/movable/screen/alert/nocell)

/obj/item/mod/core/infinite
	name = "MOD infinite core"
	icon_state = "mod-core-infinite"
	desc = "A fusion core using the rare palladium to sustain enough energy for the lifetime of the MOD's user. \
		This might be because of the slowly killing poison inside, but those are just rumors."

/obj/item/mod/core/infinite/charge_source()
	return src

/obj/item/mod/core/infinite/charge_amount()
	return INFINITY

/obj/item/mod/core/infinite/max_charge_amount()
	return INFINITY

/obj/item/mod/core/infinite/add_charge(amount)
	return TRUE

/obj/item/mod/core/infinite/subtract_charge(amount)
	return TRUE
