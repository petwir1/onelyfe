#ifndef TRAIT_CLERGYRADICAL
#define TRAIT_CLERGYRADICAL
#endif

#ifdef MIRACLE_RADIAL_DMI
#undef  MIRACLE_RADIAL_DMI
#endif
#define MIRACLE_RADIAL_DMI 'icons/mob/actions/roguespells.dmi'

#ifndef MIRACLE_MENU_RECHARGE
#define MIRACLE_MENU_RECHARGE (10 SECONDS)
#endif

// MOB VARS stuff

/mob/living/carbon/human
	var/miracle_points = 0
	var/church_favor = 0
	var/personal_research_points = 0

	var/unlocked_research_artefacts = FALSE
	var/unlocked_research_org_t1   = FALSE
	var/unlocked_research_org_t2   = FALSE
	var/unlocked_research_org_t3   = FALSE

	var/list/patron_relations = null

	var/list/quest_ui_entries = null
	var/quest_reroll_charges = 0
	var/quest_reroll_last_ds = 0


var/global/list/NOC_MIRACLE_STOCK = list(
	list(
		"id" = "greater_diagnose",
		"name" = "Greater Diagnose",
		"desc" = "Upgrades Diagnose into Greater Diagnose.",
		"cost" = 3,
		"type" = /obj/effect/proc_holder/spell/invoked/diagnose/greater,
		"requires" = /obj/effect/proc_holder/spell/invoked/diagnose,
		"replace" = /obj/effect/proc_holder/spell/invoked/diagnose
	)
)


// -------------------------------------------------------
// SPELL
// -------------------------------------------------------

/obj/effect/proc_holder/spell/self/learnmiracle
	name = "Miracles"
	desc = "Open miracle actions."
	miracle = TRUE
	devotion_cost = 0
	recharge_time = MIRACLE_MENU_RECHARGE
	chargetime = 0
	chargedrain = 0
	associated_skill = /datum/skill/magic/holy
	overlay_state = "startmiracle"

	var/current_org_tab = "none"   // none t1 or t2 or t3
	var/current_art_tab = "none"   // none patron_name
	var/current_rel_tab = "none"   // none ten or shunned
	var/current_learn_tab = "none" // none patron_name
	var/current_path_tab = "none"  // none or pestra or malum or noc

//Helpers are from here 

/obj/effect/proc_holder/spell/self/learnmiracle/proc/_has_clergy_access(mob/living/carbon/human/H, silent = FALSE)
	if(!H || !H.mind)
		return FALSE

	if(!HAS_TRAIT(H, TRAIT_CLERGYRADICAL))
		if(!silent)
			to_chat(H, span_warning("Only clergy may use miracles."))
		return FALSE

	return TRUE

/obj/effect/proc_holder/spell/self/learnmiracle/proc/_get_spell_instance(mob/living/carbon/human/H, typepath)
	if(!H || !H.mind || !ispath(typepath, /obj/effect/proc_holder/spell))
		return null

	for(var/obj/effect/proc_holder/spell/S in H.mind.spell_list)
		if(S.type == typepath)
			return S

	return null

/obj/effect/proc_holder/spell/self/learnmiracle/proc/_has_spell_type(mob/living/carbon/human/H, typepath)
	return !!_get_spell_instance(H, typepath)

/obj/effect/proc_holder/spell/self/learnmiracle/proc/_spell_name_from_type(typepath)
	if(!ispath(typepath, /obj/effect/proc_holder/spell))
		return "[typepath]"

	var/obj/effect/proc_holder/spell/T = new typepath
	var/nm = "[typepath]"
	if(T && length(T.name))
		nm = T.name
	if(T)
		qdel(T)
	return nm


// LEARN

/obj/effect/proc_holder/spell/self/learnmiracle/proc/do_learn_miracle(mob/user)
	if(!user || !user.mind)
		return

	var/mob/living/carbon/human/H = istype(user, /mob/living/carbon/human) ? user : null
	if(!H)
		return

	if(!_has_clergy_access(H))
		return

	if(!H.devotion || !H.devotion.patron)
		to_chat(user, span_warning("Your faith has no patron."))
		return

	open_learn_ui(H)


// LEARN UI

/obj/effect/proc_holder/spell/self/learnmiracle/proc/open_learn_ui(mob/living/carbon/human/H)
	if(!H)
		return
	if(!_has_clergy_access(H))
		return

	var/list/buckets = _build_learn_buckets(H, FALSE)

	build_divine_patrons_index()
	build_inhumen_patrons_index()

	var/list/names_div = list()
	for(var/pn1 in divine_patrons_index)
		names_div += "[pn1]"
	names_div = sortList(names_div)

	var/list/names_inh = list()
	for(var/pn2 in inhumen_patrons_index)
		names_inh += "[pn2]"
	names_inh = sortList(names_inh)

	var/sh_unl = _shunned_relations_unlocked(H)

	var/html = "<center><h3>Learn Miracles</h3></center><hr>"
	html += "Favor: <b>[H.church_favor]</b> | MP: <b>[H.miracle_points]</b><hr>"

	var/list/nav = list()

	if(src.current_learn_tab == "none")
		nav += "<b>None</b>"
	else
		nav += "<a href='?src=[REF(src)];learntab=none'>None</a>"

	for(var/n in names_div)
		var/relv = H.patron_relations && (n in H.patron_relations) ? H.patron_relations[n] : 0
		if(relv > 0)
			nav += (src.current_learn_tab == "[n]") ? "<b>[n]</b>" : "<a href='?src=[REF(src)];learntab=[n]'>[n]</a>"
		else
			nav += "<span style='color:#7f8c8d'>[n]</span>"

	for(var/n2 in names_inh)
		var/relv2 = H.patron_relations && (n2 in H.patron_relations) ? H.patron_relations[n2] : 0
		if(sh_unl && relv2 > 0)
			nav += (src.current_learn_tab == "[n2]") ? "<b>[n2]</b>" : "<a href='?src=[REF(src)];learntab=[n2]'>[n2]</a>"
		else
			nav += "<span style='color:#7f8c8d'>[n2]</span>"

	html += jointext(nav, " | ") + "<br><br>"

	var/list/show_list = list()

	if(src.current_learn_tab != "none")
		if(islist(buckets[src.current_learn_tab]) && length(buckets[src.current_learn_tab]))
			show_list += src.current_learn_tab

	if(!show_list.len)
		if(src.current_learn_tab == "none")
			html += "<i>Select a patron above to see their miracles.</i>"
		else
			html += "<i>No miracles available for this patron.</i>"
	else
		for(var/pn3 in show_list)
			var/list/L = buckets[pn3]
			if(!islist(L) || !L.len)
				continue

			html += "<b>[html_attr(pn3)]</b><br>"
			html += "<table width='100%' cellspacing='2' cellpadding='2'>"
			html += "<tr><th align='left'>Miracle</th><th>Description</th><th width='50'>Tier</th><th width='100'>Cost</th><th width='140'>Action</th></tr>"

			for(var/entry in L)
				var/list/E = entry
				var/nm      = "[E["name"]]"
				var/desc    = "[E["desc"]]"
				var/tier    = E["tier"]
				var/cost    = E["cost"]
				var/txtpath = "[E["type"]]"
				var/is_learned = E["learned"]

				html += "<tr>"
				html += "<td><b>[html_attr(nm)]</b></td>"
				html += "<td>[html_attr(desc)]</td>"
				html += "<td align='center'>[tier]</td>"
				html += "<td align='center'>[cost] MP</td>"
				html += "<td align='center'>"

				if(is_learned)
					html += "<span style='color:#2ecc71'>Learned</span>"
				else if(H.miracle_points >= cost)
					html += "<a href='?src=[REF(src)];learnspell=[txtpath]'>Learn</a>"
				else
					html += "<span style='color:#7f8c8d'>Not enough MP</span>"

				html += "</td></tr>"
			html += "</table><br>"

	var/datum/browser/B = new(H, "MIRACLE_LEARN", "", 720, 620)
	B.set_content(html)
	B.open()


// PATH OF PESTRA AKA ORGAN SLOP

/obj/effect/proc_holder/spell/self/learnmiracle/proc/_organs_shop_block(mob/living/carbon/human/H)
	var/html = ""
	html += "<b>Path of Pestra</b><br>"
	html += "<div style='color:#7f8c8d'>Flesh, healing, surgery and replacement.</div><br>"

	var/any_unlocked = (H.unlocked_research_org_t1 || H.unlocked_research_org_t2 || H.unlocked_research_org_t3)
	if(!any_unlocked)
		html += "<i>Unlock organ studies first.</i>"
		return html

	var/list/navO = list()
	if(src.current_org_tab == "none")
		navO += "<b>None</b>"
	else
		navO += "<a href='?src=[REF(src)];orgtab=none'>None</a>"

	if(H.unlocked_research_org_t1)
		navO += (src.current_org_tab == "t1") ? "<b>T1</b>" : "<a href='?src=[REF(src)];orgtab=t1'>T1</a>"
	if(H.unlocked_research_org_t2)
		navO += (src.current_org_tab == "t2") ? "<b>T2</b>" : "<a href='?src=[REF(src)];orgtab=t2'>T2</a>"
	if(H.unlocked_research_org_t3)
		navO += (src.current_org_tab == "t3") ? "<b>T3</b>" : "<a href='?src=[REF(src)];orgtab=t3'>T3</a>"

	html += jointext(navO, " | ") + "<br><br>"

	if(src.current_org_tab == "none")
		html += "<i>Choose a tier to buy organs.</i>"
		return html

	var/price = 0
	if(src.current_org_tab == "t1")
		price = ORG_PRICE_T1
	else if(src.current_org_tab == "t2")
		price = ORG_PRICE_T2
	else if(src.current_org_tab == "t3")
		price = ORG_PRICE_T3

	html += "<table width='100%' cellspacing='2' cellpadding='2'>"
	html += "<tr><th align='left'>Organ</th><th width='180'>Action</th></tr>"

	var/list/labels = list("eyes","stomach","liver","heart","lungs")
	for(var/L in labels)
		html += "<tr><td>[capitalize(L)]</td><td align='center'>"
		if(H.church_favor >= price)
			html += "<a href='?src=[REF(src)];buyorg=[src.current_org_tab];item=[L]'>Buy ([price] Favor)</a>"
		else
			html += "<span style='color:#7f8c8d'>Buy ([price] Favor)</span>"
		html += "</td></tr>"

	html += "</table>"
	return html


// PATH OF MALUM OLD ARTEFACTS RAB

/obj/effect/proc_holder/spell/self/learnmiracle/proc/_artefacts_shop_block(mob/living/carbon/human/H)
	var/html = ""
	html += "<b>Path of Malum</b><br>"
	html += "<div style='color:#7f8c8d'>Sacred tools, relics and crafted patron artefacts.</div><br>"

	if(!H.unlocked_research_artefacts)
		html += "<i>Unlock Artefacts study first.</i>"
		return html

	build_divine_patrons_index()

	var/list/nav = list()
	if(src.current_art_tab == "none")
		nav += "<b>None</b>"
	else
		nav += "<a href='?src=[REF(src)];arttab=none'>None</a>"

	var/list/names2 = list()
	for(var/n2 in divine_patrons_index)
		names2 += "[n2]"
	names2 = sortList(names2)

	for(var/n2 in names2)
		if(src.current_art_tab == "[n2]")
			nav += "<b>[n2]</b>"
		else
			nav += "<a href='?src=[REF(src)];arttab=[n2]'>[n2]</a>"

	html += jointext(nav, " | ") + "<br><br>"

	if(src.current_art_tab == "none")
		html += "<i>Select a patron to view artefacts.</i>"
		return html

	var/rec2 = divine_patrons_index[src.current_art_tab]
	if(!rec2)
		html += "<i>Unknown patron.</i>"
		return html

	var/domain2 = "[rec2["domain"]]"
	var/desc2   = "[rec2["desc"]]"

	html += "<b>[src.current_art_tab]</b><br>"
	if(length(domain2))
		html += "<i>[domain2]</i><br>"
	if(length(desc2))
		html += "<div style='color:#7f8c8d'>[desc2]</div>"
	html += "<br>"

	var/list/art_list = PATRON_ARTIFACTS ? PATRON_ARTIFACTS[src.current_art_tab] : null
	if(islist(art_list) && art_list.len)
		html += "<table width='100%' cellspacing='2' cellpadding='2'>"
		html += "<tr><th align='left'>Artefact</th><th width='160'>Action</th></tr>"

		for(var/T in art_list)
			var/name_txt = "[T]"
			var/obj/O = new T
			if(O && length(O.name))
				name_txt = O.name
			if(O)
				qdel(O)

			html += "<tr><td>[html_attr(name_txt)]</td><td align='center'>"
			if(H.church_favor >= ARTEFACT_PRICE_FAVOR)
				html += "<a href='?src=[REF(src)];buyart=[src.current_art_tab];item=[T]'>Buy ([ARTEFACT_PRICE_FAVOR] Favor)</a>"
			else
				html += "<span style='color:#7f8c8d'>Buy ([ARTEFACT_PRICE_FAVOR] Favor)</span>"
			html += "</td></tr>"

		html += "</table>"
	else
		html += "<i>No artefacts listed for this patron.</i>"

	return html


// PATH OF NOC - i dunno do I even want it

/obj/effect/proc_holder/spell/self/learnmiracle/proc/_noc_shop_block(mob/living/carbon/human/H)
	var/html = ""
	html += "<b>Path of Noc</b><br>"
	html += "<div style='color:#7f8c8d'>Rare miracle upgrades and forbidden refinements.</div><br>"

	if(!islist(NOC_MIRACLE_STOCK) || !NOC_MIRACLE_STOCK.len)
		html += "<i>No miracles configured.</i>"
		return html

	html += "<table width='100%' cellspacing='2' cellpadding='2'>"
	html += "<tr><th align='left'>Miracle</th><th>Description</th><th width='90'>Cost</th><th width='180'>Action</th></tr>"

	for(var/entry in NOC_MIRACLE_STOCK)
		var/list/E = entry
		if(!islist(E))
			continue

		var/id        = "[E["id"]]"
		var/nm        = "[E["name"]]"
		var/desc      = "[E["desc"]]"
		var/cost      = E["cost"]
		var/typepath  = E["type"]
		var/reqpath   = E["requires"]

		var/already_has = _has_spell_type(H, typepath)
		var/req_ok = TRUE
		if(reqpath)
			req_ok = _has_spell_type(H, reqpath)

		html += "<tr>"
		html += "<td><b>[html_attr(nm)]</b></td>"
		html += "<td>[html_attr(desc)]</td>"
		html += "<td align='center'>[cost] MP</td>"
		html += "<td align='center'>"

		if(already_has)
			html += "<span style='color:#2ecc71'>Learned</span>"
		else if(!req_ok)
			html += "<span style='color:#e67e22'>Requires [_spell_name_from_type(reqpath)]</span>"
		else if(H.miracle_points >= cost)
			html += "<a href='?src=[REF(src)];buynoc=[id]'>Buy</a>"
		else
			html += "<span style='color:#7f8c8d'>Not enough MP</span>"

		html += "</td></tr>"

	html += "</table>"
	return html


// RESEARCH UI

/obj/effect/proc_holder/spell/self/learnmiracle/proc/open_research_ui(mob/user)
	var/mob/living/carbon/human/H = istype(user, /mob/living/carbon/human) ? user : null
	if(!H)
		return
	if(!_has_clergy_access(H))
		return

	_ensure_relations(H)
	_update_reroll_charges(H)

	var/rp = H.personal_research_points
	var/fv = H.church_favor
	var/mp = H.miracle_points

	var/html = "<center><h3>Miracle Research</h3></center><hr>"
	html += "<b>Research Points:</b> [rp]<br>"
	html += "<b>Favor:</b> [fv]<br>"
	html += "<b>Miracle Points:</b> [mp]<br>"
	html += "<hr>"

	if(fv >= RESEARCH_RP_PRICE_FLAVOR)
		html += "<a href='?src=[REF(src)];buyrp=1'>Buy 1 RP ([RESEARCH_RP_PRICE_FLAVOR] Favor)</a><br>"
	else
		html += "<span style='color:#7f8c8d'>Buy 1 RP ([RESEARCH_RP_PRICE_FLAVOR] Favor)</span><br>"

	if(fv >= MIRACLE_MP_PRICE_FLAVOR)
		html += "<a href='?src=[REF(src)];buymp=1'>Buy 1 MP ([MIRACLE_MP_PRICE_FLAVOR] Favor)</a><br>"
	else
		html += "<span style='color:#7f8c8d'>Buy 1 MP ([MIRACLE_MP_PRICE_FLAVOR] Favor)</span><br>"

	// ---------------- STUDIES ----------------
	html += "<hr><b>Studies</b><br>"
	html += "<table width='100%' cellspacing='2' cellpadding='2'>"
	html += "<tr><th align='left'>Study</th><th width='110'>Status</th><th width='220'>Action</th></tr>"

	html += "<tr><td>Artefacts</td><td>[status_yn(H.unlocked_research_artefacts)]</td><td align='center'>"
	if(!H.unlocked_research_artefacts)
		if(rp >= COST_ARTEFACTS)
			html += "<a href='?src=[REF(src)];unlock=artefacts'>Unlock ([COST_ARTEFACTS] RP)</a>"
		else
			html += "<span style='color:#7f8c8d'>Unlock ([COST_ARTEFACTS] RP)</span>"
	else
		html += "<span style='color:#7f8c8d'>-</span>"
	html += "</td></tr>"

	html += "<tr><td>Organs T1</td><td>[status_yn(H.unlocked_research_org_t1)]</td><td align='center'>"
	if(!H.unlocked_research_org_t1)
		if(rp >= COST_ORG_T1)
			html += "<a href='?src=[REF(src)];unlock=org_t1'>Unlock ([COST_ORG_T1] RP)</a>"
		else
			html += "<span style='color:#7f8c8d'>Unlock ([COST_ORG_T1] RP)</span>"
	else
		html += "<span style='color:#7f8c8d'>-</span>"
	html += "</td></tr>"

	html += "<tr><td>Organs T2</td><td>[status_yn(H.unlocked_research_org_t2)]</td><td align='center'>"
	if(!H.unlocked_research_org_t2)
		if(rp >= COST_ORG_T2)
			html += "<a href='?src=[REF(src)];unlock=org_t2'>Unlock ([COST_ORG_T2] RP)</a>"
		else
			html += "<span style='color:#7f8c8d'>Unlock ([COST_ORG_T2] RP)</span>"
	else
		html += "<span style='color:#7f8c8d'>-</span>"
	html += "</td></tr>"

	html += "<tr><td>Organs T3</td><td>[status_yn(H.unlocked_research_org_t3)]</td><td align='center'>"
	if(!H.unlocked_research_org_t3)
		if(rp >= COST_ORG_T3)
			html += "<a href='?src=[REF(src)];unlock=org_t3'>Unlock ([COST_ORG_T3] RP)</a>"
		else
			html += "<span style='color:#7f8c8d'>Unlock ([COST_ORG_T3] RP)</span>"
	else
		html += "<span style='color:#7f8c8d'>-</span>"
	html += "</td></tr>"

	var/sh_unl = _shunned_relations_unlocked(H)
	html += "<tr><td>Shunned Knowledges</td><td>[status_yn(sh_unl)]</td><td align='center'>"
	if(!sh_unl)
		if(H.personal_research_points >= UNLOCK_SHUNNED_RP)
			html += "<a href='?src=[REF(src)];unlock_shunned_rel=1'>Unlock ([UNLOCK_SHUNNED_RP] RP)</a>"
		else
			html += "<span style='color:#7f8c8d'>Unlock ([UNLOCK_SHUNNED_RP] RP)</span>"
	else
		html += "<span style='color:#7f8c8d'>-</span>"
	html += "</td></tr>"

	html += "</table>"

	// ---------------- PATHS ----------------
	html += "<hr><b>Paths</b><br>"
	var/list/path_nav = list()

	if(src.current_path_tab == "none")
		path_nav += "<b>None</b>"
	else
		path_nav += "<a href='?src=[REF(src)];pathtab=none'>None</a>"

	path_nav += (src.current_path_tab == "pestra") ? "<b>Path of Pestra</b>" : "<a href='?src=[REF(src)];pathtab=pestra'>Path of Pestra</a>"
	path_nav += (src.current_path_tab == "malum")  ? "<b>Path of Malum</b>"  : "<a href='?src=[REF(src)];pathtab=malum'>Path of Malum</a>"
	path_nav += (src.current_path_tab == "noc")    ? "<b>Path of Noc</b>"    : "<a href='?src=[REF(src)];pathtab=noc'>Path of Noc</a>"

	html += jointext(path_nav, " | ") + "<br><br>"

	if(src.current_path_tab == "pestra")
		html += _organs_shop_block(H)
	else if(src.current_path_tab == "malum")
		html += _artefacts_shop_block(H)
	else if(src.current_path_tab == "noc")
		html += _noc_shop_block(H)
	else
		html += "<i>Select a path above.</i>"

	// ---------------- RELATIONS ----------------
	var/list/nav_bits = list()
	nav_bits += (src.current_rel_tab == "none") ? "<b>Relations: None</b>" : "<a href='?src=[REF(src)];reltab=none'>Relations: None</a>"
	nav_bits += (src.current_rel_tab == "ten")  ? "<b>Ten</b>" : "<a href='?src=[REF(src)];reltab=ten'>Ten</a>"

	if(_shunned_relations_unlocked(H))
		nav_bits += (src.current_rel_tab == "shunned") ? "<b>Ascendants</b>" : "<a href='?src=[REF(src)];reltab=shunned'>Shunned</a>"
	else
		nav_bits += "<span style='color:#7f8c8d'>Ascendants</span>"

	html += "<hr>" + jointext(nav_bits, " | ") + "<br>"

	var/is_templar = _is_templar(H)
	var/is_churchling = _is_churchling(H)
	var/rel_cap = is_templar ? 2 : (is_churchling ? 1 : 4)

	if(src.current_rel_tab == "ten" || (src.current_rel_tab == "shunned" && _shunned_relations_unlocked(H)))
		var/list/idx = (src.current_rel_tab == "shunned") ? inhumen_patrons_index : divine_patrons_index
		if(idx && idx.len)
			html += "<br><b>[src.current_rel_tab == "shunned" ? "Shunned" : "Ten"] - Patron Relationships</b><br>"
			html += "<div style='margin:6px 0; padding:8px; background:#222831; border-radius:6px;'>"
			html += "<div><i>Relation chart (0..[rel_cap]):</i></div>"

			var/list/names_chart = list()
			for(var/nc in idx)
				names_chart += "[nc]"
			names_chart = sortList(names_chart)

			var/my_patron = ""
			if(H.devotion && H.devotion.patron && ("name" in H.devotion.patron.vars))
				my_patron = "[H.devotion.patron.vars["name"]]"

			for(var/gn in names_chart)
				var/curv = H.patron_relations && (gn in H.patron_relations) ? H.patron_relations[gn] : 0
				if(curv > rel_cap)
					curv = rel_cap

				var/perc = round((curv * 100) / rel_cap)
				if(perc < 0)
					perc = 0
				if(perc > 100)
					perc = 100

				var/bar_color = (gn == my_patron) ? "#2ecc71" : "#3498db"

				html += "<div style='margin:6px 0;'>"
				html += "<div style='font-size:12px;color:#ecf0f1;'>[html_attr(gn)] - <b>[curv]</b>/[rel_cap]</div>"
				html += "<div style='background:#2c3e50;height:10px;border-radius:6px;overflow:hidden;'>"
				html += "<div style='width:[perc]%;height:10px;background:[bar_color];'></div>"
				html += "</div></div>"

			html += "</div><br>"

			html += "<table width='100%' cellspacing='2' cellpadding='2'>"
			html += "<tr><th align='left'>Patron</th><th>Domain</th><th width='80'>Level</th><th width='220'>Action</th></tr>"

			var/list/names = list()
			for(var/n in idx)
				names += "[n]"
			names = sortList(names)

			for(var/n in names)
				var/list/rec = idx[n]
				var/dom = "[rec["domain"]]"
				var/cur = H.patron_relations && (n in H.patron_relations) ? H.patron_relations[n] : 0
				if(cur > rel_cap)
					cur = rel_cap

				html += "<tr>"
				html += "<td><b>[html_attr(n)]</b></td>"
				html += "<td>[html_attr(dom)]</td>"
				html += "<td align='center'><b>[cur]</b>/[rel_cap]</td>"
				html += "<td align='center'>"

				if(H.devotion && H.devotion.patron && ("name" in H.devotion.patron.vars) && ("[H.devotion.patron.vars["name"]]" == n))
					html += "<span style='color:#2ecc71'>Own patron (max).</span>"
				else
					if(cur >= rel_cap)
						html += "<span style='color:#2ecc71'>Maxed</span>"
					else
						var/next = cur + 1
						if(next > rel_cap)
							next = rel_cap

						var/cost = (next == 1) ? 1 : (next == 2) ? 2 : (next == 3) ? 3 : 4
						var/can = TRUE
						if(src.current_rel_tab == "shunned" && !_shunned_relations_unlocked(H))
							can = FALSE

						if(can && H.personal_research_points >= cost)
							html += "<a href='?src=[REF(src)];relten_up=[n]'>Upgrade to [next] ([cost] RP)</a>"
						else
							html += "<span style='color:#7f8c8d'>Upgrade to [next] ([cost] RP)</span>"

				html += "</td></tr>"

			html += "</table>"
		else
			html += "<i>No patrons found.</i>"
	else
		html += "<i>Relations hidden (None).</i>"

	var/datum/browser/B = new(user, "MIRACLE_RESEARCH", "", 760, 900)
	B.set_content(html)
	B.open()


// QUESTS UI

/obj/effect/proc_holder/spell/self/learnmiracle/proc/open_quests_ui(mob/user)
	var/mob/living/carbon/human/H = istype(user, /mob/living/carbon/human) ? user : null
	if(!H)
		return
	if(!_has_clergy_access(H))
		return

	var/init_needed = TRUE
	if(islist(H.quest_ui_entries))
		if(H.quest_ui_entries.len >= 1)
			init_needed = FALSE

	if(init_needed)
		H.quest_ui_entries = _rt_build_player_quest_set(H)
		if(!H.quest_reroll_last_ds)
			H.quest_reroll_last_ds = world.time

	_update_reroll_charges(H)

	var/charges = H.quest_reroll_charges
	var/next_left_ds = max(0, QUEST_COOLDOWN_DS - (world.time - H.quest_reroll_last_ds))
	var/left_s  = round(next_left_ds / 10)
	var/mins    = left_s / 60
	var/secs    = left_s % 60
	var/secs_str = (secs < 10) ? "0[secs]" : "[secs]"

	var/html = "<center><h3 style='color:#3498db;margin:6px 0;'>Parish Assignments</h3>"
	if(charges >= 1)
		html += "<div style='margin-top:6px;'><a href='?src=[REF(src)];q_reroll=1' style='background:#8e44ad;color:#fff;padding:3px 8px;border-radius:6px;text-decoration:none;'><b>Reroll (charges: [charges])</b></a></div>"
	else
		html += "<div style='margin-top:6px;color:#9b59b6;'>Next charge in: <b>[mins]:[secs_str]</b></div>"

	html += "<div style='color:#e74c3c; text-align:center; margin:6px 0;'>"
	html += "<b>How it works:</b><br>"
	html += "You get four different quest themes.<br>"
	html += "Each quest can have <u>Easy / Medium / Hard</u> variants.<br>"
	html += "When you click <b>Get special item</b> on one row, you lock that quest to that difficulty and receive a quest item.<br>"
	html += "Other rows for that quest lock until reroll.<br>"
	html += "Quest items are bound to their owner, do not expire on their own, and reward only the owner upon completion."
	html += "</div></center><hr>"

	var/quest_count = islist(H.quest_ui_entries) ? H.quest_ui_entries.len : 0

	for(var/i = 1, i <= quest_count, i++)
		var/list/slot = H.quest_ui_entries[i]
		if(!islist(slot))
			continue

		var/quest_title = "[slot["title"]]"
		var/accepted_diff = slot["accepted_diff"]
		if(!istext(accepted_diff))
			accepted_diff = ""

		html += "<div style='padding:10px;'>"
		html += "<center><b style='font-size:14px; color:#ecf0f1; background:#34495e; padding:2px 8px; border-radius:6px;'>[quest_title]</b></center>"
		html += "<br>"

		html += "<table width='100%' cellspacing='2' cellpadding='2' style='text-align:center;'>"
		html += "<tr style='background:#2c3e50;color:#ecf0f1;'><th>Difficulty</th><th>Task</th><th>Reward</th><th>Action</th></tr>"

		var/list/diffs = slot["difficulties"]
		if(islist(diffs))
			var/list/diff_order = list()
			if("easy" in diffs)   diff_order += "easy"
			if("medium" in diffs) diff_order += "medium"
			if("hard" in diffs)   diff_order += "hard"
			for(var/other in diffs)
				if(!(other in diff_order))
					diff_order += other

			for(var/diff_key in diff_order)
				if(!(diff_key in diffs))
					continue

				var/list/D = diffs[diff_key]
				if(!islist(D))
					continue

				var/diff_label = uppertext("[diff_key]")
				var/desc_txt   = "[D["desc"]]"
				var/reward_txt = "[D["reward"]]"
				var/spawned    = D["spawned"]
				var/locked = (length(accepted_diff) && (accepted_diff != diff_key))

				html += "<tr>"
				html += "<td><b>[diff_label]</b></td>"
				html += "<td>[desc_txt]</td>"
				html += "<td style='color:#2ecc71'><b>[reward_txt]</b> Favor</td>"
				html += "<td>"

				if(locked)
					html += "<span style='display:inline-block; padding:4px 10px; border-radius:6px; background:#7f8c8d; color:#ecf0f1;'>Locked</span>"
				else
					if(spawned)
						html += "<span style='display:inline-block; padding:4px 10px; border-radius:6px; background:#7f8c8d; color:#ecf0f1;'>Item spawned</span>"
					else
						html += "<a href='?src=[REF(src)];q_spawn=[i];diff=[diff_key]' style='display:inline-block; padding:4px 10px; border-radius:6px; background:#1abc9c; color:#ffffff; text-decoration:none;'>Get special item</a>"

				html += "</td></tr>"

		html += "</table>"
		html += "</div>"

		if(i < quest_count)
			html += "<hr style='border-color:#2c3e50;'>"

	var/datum/browser/B2 = new(user, "MIRACLE_QUESTS", "", 720, 780)
	B2.set_content(html)
	B2.open()


// TOPIC

/obj/effect/proc_holder/spell/self/learnmiracle/Topic(href, href_list)
	. = ..()
	if(!usr || !istype(usr, /mob/living/carbon/human))
		return

	var/mob/living/carbon/human/H = usr
	if(!_has_clergy_access(H))
		return

	_ensure_relations(H)

	// ---------------- QUEST REROLL ----------------

	if(href_list["q_reroll"])
		_update_reroll_charges(H)
		if(H.quest_reroll_charges <= 0)
			open_quests_ui(H)
			return

		H.quest_ui_entries = _rt_build_player_quest_set(H)
		H.quest_reroll_charges = max(0, H.quest_reroll_charges - 1)
		to_chat(H, span_notice("Quests rerolled. Charges left: [H.quest_reroll_charges]."))
		open_quests_ui(H)
		return

	// ---------------- QUEST SPAWN ----------------
	if(href_list["q_spawn"])
		var/q_index = text2num(href_list["q_spawn"])
		var/diff_key = lowertext(href_list["diff"])

		var/quest_len = islist(H.quest_ui_entries) ? H.quest_ui_entries.len : 0
		if(!isnum(q_index) || q_index < 1 || q_index > quest_len)
			open_quests_ui(H)
			return

		var/list/slot = H.quest_ui_entries[q_index]
		if(!islist(slot))
			open_quests_ui(H)
			return

		var/list/diffs = slot["difficulties"]
		if(!islist(diffs) || !(diff_key in diffs))
			open_quests_ui(H)
			return

		var/accepted_diff = slot["accepted_diff"]
		if(!istext(accepted_diff))
			accepted_diff = ""

		if(length(accepted_diff) && accepted_diff != diff_key)
			to_chat(H, span_warning("This quest is already locked to [uppertext(accepted_diff)]."))
			open_quests_ui(H)
			return

		var/list/D = diffs[diff_key]
		if(!islist(D))
			open_quests_ui(H)
			return

		if(D["spawned"])
			to_chat(H, span_warning("The quest item has already been granted."))
			open_quests_ui(H)
			return

		var/typepath = D["token_path"]
		if(!typepath)
			to_chat(H, span_warning("Token type not found."))
			open_quests_ui(H)
			return

		var/obj/item/quest_token/QI = new typepath(H)
		if(!QI)
			to_chat(H, span_warning("Failed to spawn the quest item."))
			open_quests_ui(H)
			return

		var/success = FALSE
		if(ismob(H) && hascall(H, "put_in_hands"))
			success = call(H, "put_in_hands")(QI)
		if(!success)
			var/turf/TT = get_turf(H)
			if(TT)
				QI.forceMove(TT)

		if(istype(QI, /obj/item/quest_token))
			var/obj/item/quest_token/QBASE = QI
			if(D["reward"])
				QBASE.reward_amount = D["reward"]

		var/list/P = D["params"]
		if(islist(P))
			if(istype(QI, /obj/item/quest_token/coin_chest))
				var/obj/item/quest_token/coin_chest/CC = QI
				if(P["required_sum"])
					CC.required_sum = P["required_sum"]

			if(istype(QI, /obj/item/quest_token/skill_bless))
				var/obj/item/quest_token/skill_bless/SK = QI
				if(P["required_skills"])
					SK.required_skills = P["required_skills"]

			if(istype(QI, /obj/item/quest_token/blood_draw))
				var/obj/item/quest_token/blood_draw/BD = QI
				if(P["required_race_keys"])
					BD.required_race_keys = P["required_race_keys"]

			if(istype(QI, /obj/item/quest_token/ration_delivery))
				var/obj/item/quest_token/ration_delivery/RD = QI
				if(P["required_job_types"])
					RD.required_job_types = P["required_job_types"]

			if(istype(QI, /obj/item/quest_token/donation_box))
				var/obj/item/quest_token/donation_box/DB = QI
				if(P["need_types"])
					DB.need_types = P["need_types"]

			if(istype(QI, /obj/item/quest_token/sermon_minor))
				var/obj/item/quest_token/sermon_minor/SM = QI
				if(P["required_patron_names"])
					SM.required_patron_names = P["required_patron_names"]

			if(istype(QI, /obj/item/quest_token/reliquary))
				var/obj/item/quest_token/reliquary/RL = QI
				if(P["bonus_patron_names"])
					RL.bonus_patron_names = P["bonus_patron_names"]

			if(istype(QI, /obj/item/quest_token/flaw_aid))
				var/obj/item/quest_token/flaw_aid/FA = QI
				if(P["required_flaw_types"])
					FA.required_flaw_types = P["required_flaw_types"]

		D["spawned"] = TRUE
		diffs[diff_key] = D
		slot["accepted_diff"] = diff_key
		slot["difficulties"]  = diffs
		H.quest_ui_entries[q_index] = slot

		to_chat(H, span_notice("A special quest item has been granted: [QI.name]."))
		open_quests_ui(H)
		return

	// ---------------- RELATION TAB ----------------
	if(href_list["reltab"])
		var/tb = lowertext(href_list["reltab"])
		if(tb == "ten")
			src.current_rel_tab = "ten"
		else if(tb == "shunned")
			if(_shunned_relations_unlocked(H))
				src.current_rel_tab = "shunned"
			else
				src.current_rel_tab = "none"
		else
			src.current_rel_tab = "none"

		open_research_ui(H)
		return

	// ---------------- RELATION UPGRADE ----------------
	if(href_list["relten_up"])
		var/god = href_list["relten_up"]
		build_divine_patrons_index()
		build_inhumen_patrons_index()

		if(!(god in divine_patrons_index) && !(god in inhumen_patrons_index))
			open_research_ui(H)
			return

		if((god in inhumen_patrons_index))
			if(!_shunned_relations_unlocked(H))
				if(!(H.devotion && H.devotion.patron && "[H.devotion.patron.vars["name"]]" == god))
					open_research_ui(H)
					return

		if(H.devotion && H.devotion.patron && ("name" in H.devotion.patron.vars))
			var/myname = "[H.devotion.patron.vars["name"]]"
			if(god == myname)
				open_research_ui(H)
				return

		var/cur = H.patron_relations[god]
		if(!isnum(cur))
			cur = 0

		if(_is_templar(H) && cur >= 2)
			open_research_ui(H)
			return

		if(_is_churchling(H) && cur >= 1)
			open_research_ui(H)
			return

		if(cur >= 4)
			open_research_ui(H)
			return

		var/next = cur + 1

		if(_is_templar(H) && next > 2)
			open_research_ui(H)
			return

		if(_is_churchling(H) && next > 1)
			open_research_ui(H)
			return

		var/cost = (next == 1) ? 1 : (next == 2) ? 2 : (next == 3) ? 3 : 4
		if(H.personal_research_points < cost)
			open_research_ui(H)
			return

		H.personal_research_points = max(0, H.personal_research_points - cost)
		H.patron_relations[god] = next
		to_chat(H, span_notice("Relations with [god] increased to [next]."))
		open_research_ui(H)
		return

	// ---------------- LEARN TAB ----------------
	if(href_list["learntab"])
		var/tb2 = href_list["learntab"]

		if(tb2 == "none")
			src.current_learn_tab = "none"
			open_learn_ui(H)
			return

		build_divine_patrons_index()
		build_inhumen_patrons_index()

		var/can_select = FALSE

		if(tb2 in divine_patrons_index)
			var/relv = H.patron_relations && (tb2 in H.patron_relations) ? H.patron_relations[tb2] : 0
			if(relv > 0)
				can_select = TRUE

		if(!can_select && (tb2 in inhumen_patrons_index))
			if(_shunned_relations_unlocked(H))
				var/relv2 = H.patron_relations && (tb2 in H.patron_relations) ? H.patron_relations[tb2] : 0
				if(relv2 > 0)
					can_select = TRUE

		if(can_select)
			src.current_learn_tab = "[tb2]"

		open_learn_ui(H)
		return

	// ---------------- LEARN SPELL ----------------
	if(href_list["learnspell"])
		var/txt = href_list["learnspell"]
		var/typepath3 = text2path(txt)

		if(!ispath(typepath3, /obj/effect/proc_holder/spell))
			open_learn_ui(H)
			return

		var/obj/effect/proc_holder/spell/S = new typepath3
		if(!S)
			open_learn_ui(H)
			return

		if(H?.mind)
			for(var/obj/effect/proc_holder/spell/K in H.mind.spell_list)
				if(K.type == typepath3)
					qdel(S)
					to_chat(H, span_warning("You already know this one!"))
					open_learn_ui(H)
					return

		var/my_patron2 = ""
		if(H.devotion && H.devotion.patron && ("name" in H.devotion.patron.vars))
			my_patron2 = "[H.devotion.patron.vars["name"]]"

		var/tier3 = get_spell_tier(S)

		var/list/owners = get_spell_patron_names(typepath3)
		var/real_owner = ""

		if(length(my_patron2) && islist(owners) && (my_patron2 in owners))
			real_owner = my_patron2
		else if(islist(owners) && owners.len)
			var/best_name = ""
			var/best_rel = -1
			for(var/on in owners)
				if(!istext(on))
					continue
				var/r = (H.patron_relations && (on in H.patron_relations) && isnum(H.patron_relations[on])) ? H.patron_relations[on] : 0
				if(r > best_rel)
					best_rel = r
					best_name = "[on]"
			real_owner = best_name
		else
			real_owner = my_patron2

		if(!istext(real_owner) || !length(real_owner))
			qdel(S)
			open_learn_ui(H)
			return

		var/owner_rel = (real_owner == my_patron2) ? 4 : (H.patron_relations && (real_owner in H.patron_relations) ? H.patron_relations[real_owner] : 0)
		var/max_allowed = allowed_tier_by_relation(owner_rel)
		if(_is_templar(H))
			max_allowed = min(max_allowed, 2)
		if(_is_churchling(H))
			max_allowed = min(max_allowed, 1)

		if(tier3 > max_allowed)
			qdel(S)
			to_chat(H, span_warning("You lack the relation level for this miracle."))
			open_learn_ui(H)
			return

		var/cost3 = (real_owner == my_patron2) ? CLERIC_PRICE_PATRON : CLERIC_PRICE_FOREIGN
		if(H.miracle_points < cost3)
			qdel(S)
			open_learn_ui(H)
			return

		if(alert(H, "[S.desc]", "[S.name]", "Learn", "Cancel") != "Learn")
			qdel(S)
			open_learn_ui(H)
			return

		if(H.miracle_points < cost3)
			qdel(S)
			to_chat(H, span_warning("Not enough Miracle Points."))
			open_learn_ui(H)
			return

		if(H?.mind)
			for(var/obj/effect/proc_holder/spell/K2 in H.mind.spell_list)
				if(K2.type == typepath3)
					qdel(S)
					to_chat(H, span_warning("You already know this one!"))
					open_learn_ui(H)
					return

		H.miracle_points = max(0, H.miracle_points - cost3)
		H.mind.AddSpell(S)
		to_chat(H, span_notice("You have learned [S.name]."))
		open_learn_ui(H)
		return

	// ---------------- PATH TAB ----------------
	if(href_list["pathtab"])
		var/pt = lowertext(href_list["pathtab"])
		if(pt == "pestra" || pt == "malum" || pt == "noc")
			src.current_path_tab = pt
		else
			src.current_path_tab = "none"

		open_research_ui(H)
		return

	// ---------------- ORGAN TAB ----------------
	if(href_list["orgtab"])
		var/tbo = href_list["orgtab"]
		if(tbo == "none" || tbo == "t1" || tbo == "t2" || tbo == "t3")
			src.current_org_tab = tbo
		open_research_ui(H)
		return

	// ---------------- ARTEFACT TAB ----------------
	if(href_list["arttab"])
		var/tbA = href_list["arttab"]
		if(tbA == "none")
			src.current_art_tab = "none"
		else
			build_divine_patrons_index()
			if(divine_patrons_index && (tbA in divine_patrons_index))
				src.current_art_tab = "[tbA]"
			else
				src.current_art_tab = "none"

		open_research_ui(H)
		return

	// ---------------- BUY ARTEFACT ----------------
	if(href_list["buyart"])
		var/god2 = href_list["buyart"]
		var/item_txt = href_list["item"]

		build_divine_patrons_index()
		if(!(god2 in divine_patrons_index))
			open_research_ui(H)
			return

		if(item_txt)
			var/item_path = text2path(item_txt)
			if(!ispath(item_path, /obj/item))
				to_chat(H, span_warning("Invalid artefact type."))
				open_research_ui(H)
				return

			var/list/art_list = PATRON_ARTIFACTS ? PATRON_ARTIFACTS[god2] : null
			if(!islist(art_list) || !art_list.Find(item_path))
				to_chat(H, span_warning("This artefact does not belong to [god2]."))
				open_research_ui(H)
				return

			if(H.church_favor < ARTEFACT_PRICE_FAVOR)
				open_research_ui(H)
				return

			if(alert(H, "Buy [item_txt] of [god2] for [ARTEFACT_PRICE_FAVOR] Favor?", "Confirm", "Buy", "Cancel") != "Buy")
				open_research_ui(H)
				return

			var/turf/T1 = get_step(H, H.dir)
			if(!T1)
				T1 = get_turf(H)

			new item_path(T1)
			H.church_favor = max(0, H.church_favor - ARTEFACT_PRICE_FAVOR)
			to_chat(H, span_notice("You acquired an artefact of [god2]."))
			open_research_ui(H)
			return

		open_research_ui(H)
		return

	// ---------------- BUY ORGAN ----------------
	if(href_list["buyorg"])
		var/tier_buy = lowertext(href_list["buyorg"])
		var/label = lowertext(href_list["item"])

		if(!(label in list("eyes","stomach","liver","heart","lungs")))
			open_research_ui(H)
			return

		var/unlocked = FALSE
		var/price = 0

		if(tier_buy == "t1")
			unlocked = H.unlocked_research_org_t1
			price = ORG_PRICE_T1
		else if(tier_buy == "t2")
			unlocked = H.unlocked_research_org_t2
			price = ORG_PRICE_T2
		else if(tier_buy == "t3")
			unlocked = H.unlocked_research_org_t3
			price = ORG_PRICE_T3
		else
			open_research_ui(H)
			return

		if(!unlocked || H.church_favor < price)
			open_research_ui(H)
			return

		var/path_text = "/obj/item/organ/[label]/[tier_buy]"
		var/typepath2 = text2path(path_text)
		if(!typepath2)
			to_chat(H, span_warning("Organ type not found: [path_text]"))
			open_research_ui(H)
			return

		var/turf/T2 = get_step(H, H.dir)
		if(!T2)
			T2 = get_turf(H)

		new typepath2(T2)
		H.church_favor = max(0, H.church_favor - price)
		to_chat(H, span_notice("[capitalize(label)] [uppertext(tier_buy)] spawned for [price] Favor."))
		open_research_ui(H)
		return

	// ---------------- BUY NOC MIRACLE ----------------
	if(href_list["buynoc"])
		var/id_buy = "[href_list["buynoc"]]"
		var/list/chosen = null

		for(var/entryN in NOC_MIRACLE_STOCK)
			var/list/EN = entryN
			if(islist(EN) && "[EN["id"]]" == id_buy)
				chosen = EN
				break

		if(!islist(chosen))
			open_research_ui(H)
			return

		var/costN     = chosen["cost"]
		var/typeN     = chosen["type"]
		var/reqN      = chosen["requires"]
		var/replaceN  = chosen["replace"]
		var/nameN     = "[chosen["name"]]"
		var/descN     = "[chosen["desc"]]"

		if(_has_spell_type(H, typeN))
			to_chat(H, span_warning("You already know [nameN]."))
			open_research_ui(H)
			return

		if(reqN && !_has_spell_type(H, reqN))
			to_chat(H, span_warning("You must know [_spell_name_from_type(reqN)] first."))
			open_research_ui(H)
			return

		if(H.miracle_points < costN)
			to_chat(H, span_warning("Not enough Miracle Points."))
			open_research_ui(H)
			return

		if(alert(H, "[descN]", "[nameN]", "Buy", "Cancel") != "Buy")
			open_research_ui(H)
			return

		if(H.miracle_points < costN)
			to_chat(H, span_warning("Not enough Miracle Points."))
			open_research_ui(H)
			return

		if(_has_spell_type(H, typeN))
			to_chat(H, span_warning("You already know [nameN]."))
			open_research_ui(H)
			return

		if(reqN && !_has_spell_type(H, reqN))
			to_chat(H, span_warning("You must know [_spell_name_from_type(reqN)] first."))
			open_research_ui(H)
			return

		if(replaceN)
			var/obj/effect/proc_holder/spell/OLD = _get_spell_instance(H, replaceN)
			if(OLD)
				if(hascall(H.mind, "RemoveSpell"))
					call(H.mind, "RemoveSpell")(OLD)
				else
					qdel(OLD)

		var/obj/effect/proc_holder/spell/NEWN = new typeN
		if(!NEWN)
			to_chat(H, span_warning("Failed to create [nameN]."))
			open_research_ui(H)
			return

		H.miracle_points = max(0, H.miracle_points - costN)
		H.mind.AddSpell(NEWN)
		to_chat(H, span_notice("You have obtained [nameN] for [costN] MP."))
		open_research_ui(H)
		return

	// ---------------- BUY RP ----------------
	if(href_list["buyrp"])
		if(H.church_favor < RESEARCH_RP_PRICE_FLAVOR)
			open_research_ui(H)
			return

		H.church_favor = max(0, H.church_favor - RESEARCH_RP_PRICE_FLAVOR)
		H.personal_research_points++
		to_chat(H, span_notice("You gained +1 Research Point."))
		open_research_ui(H)
		return

	// ---------------- BUY MP ----------------
	if(href_list["buymp"])
		if(H.church_favor < MIRACLE_MP_PRICE_FLAVOR)
			open_research_ui(H)
			return

		H.church_favor = max(0, H.church_favor - MIRACLE_MP_PRICE_FLAVOR)
		H.miracle_points++
		to_chat(H, span_notice("You gained +1 Miracle Point."))
		open_research_ui(H)
		return

	// ---------------- UNLOCK STUDY ----------------
	if(href_list["unlock"])
		var/key = lowertext(href_list["unlock"])
		var/need = 0

		if(key == "artefacts")
			need = COST_ARTEFACTS
		else if(key == "org_t1")
			need = COST_ORG_T1
		else if(key == "org_t2")
			need = COST_ORG_T2
		else if(key == "org_t3")
			need = COST_ORG_T3
		else
			open_research_ui(H)
			return

		if(H.personal_research_points < need)
			open_research_ui(H)
			return

		H.personal_research_points = max(0, H.personal_research_points - need)

		if(key == "artefacts")
			H.unlocked_research_artefacts = TRUE
		else if(key == "org_t1")
			H.unlocked_research_org_t1 = TRUE
		else if(key == "org_t2")
			H.unlocked_research_org_t2 = TRUE
		else if(key == "org_t3")
			H.unlocked_research_org_t3 = TRUE

		to_chat(H, span_notice("Study unlocked: [key]."))
		open_research_ui(H)
		return

	// ---------------- UNLOCK SHUNNED ----------------
	if(href_list["unlock_shunned_rel"])
		if(H.personal_research_points < UNLOCK_SHUNNED_RP)
			open_research_ui(H)
			return

		H.personal_research_points = max(0, H.personal_research_points - UNLOCK_SHUNNED_RP)
		build_inhumen_patrons_index()

		if(!islist(H.patron_relations))
			H.patron_relations = list()

		for(var/nsh in inhumen_patrons_index)
			if(!(nsh in H.patron_relations))
				H.patron_relations[nsh] = 0

		to_chat(H, span_notice("Shunned knowledges unlocked."))
		open_research_ui(H)
		return


/obj/effect/proc_holder/spell/self/learnmiracle/cast(list/targets, mob/user)
	if(!istype(user, /mob/living/carbon/human))
		return

	var/mob/living/carbon/human/H = user
	if(!_has_clergy_access(H))
		return

	if(!..())
		return

	var/list/rad = list()
	rad["Learn"]    = icon(icon = MIRACLE_RADIAL_DMI, icon_state = "learnmiracle")
	rad["Quests"]   = icon(icon = MIRACLE_RADIAL_DMI, icon_state = "questmiracle")
	rad["Research"] = icon(icon = MIRACLE_RADIAL_DMI, icon_state = "researchmiracle")

	var/choice = show_radial_menu(H, H, rad, require_near = FALSE)
	if(!choice)
		return

	if(choice == "Learn")
		do_learn_miracle(H)
	else if(choice == "Research")
		open_research_ui(H)
	else if(choice == "Quests")
		open_quests_ui(H)

	return
