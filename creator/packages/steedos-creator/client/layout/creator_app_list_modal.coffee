

Template.creator_app_list_modal.helpers Creator.helpers

Template.creator_app_list_modal.helpers
	apps: ()->
		return Creator.getVisibleApps(true)

	app_objects: ()->
		objects = []
		_.each Creator.getVisibleAppsObjects(), (object_name)->
			app_obj = Creator.getObject(object_name)
			if app_obj.permissions.get().allowRead
				objects.push app_obj
		return objects

	all_objects: ()->
		objects = []
		_.each Steedos.getDisplayObjects(), (_object)->
			object = Creator.getObject(_object.name)
			if object.permissions.get().allowRead
				objects.push object
		return objects
	app_url: ()->
		if this?.url
			if /^http(s?):\/\//.test(this.url)
				return this.url
			else
				return Creator.getRelativeUrl(this.url);
		else if this._id
			return Creator.getRelativeUrl("/app/#{this._id}/");
	
	app_target: ()->
		if this?.is_new_window
			return "_blank"
		else
			return ""

	object_url: ()->
		return Steedos.absoluteUrl("/app/-/#{this.name}")

	spaceName: ->
		if Session.get("spaceId")
			space = db.spaces.findOne(Session.get("spaceId"))
			if space
				return space.name
		return t("none_space_selected_title")

	spacesSwitcherVisible: ->
		return db.spaces.find().count()>1;

	spaces: ->
		return db.spaces.find();


Template.creator_app_list_modal.events
	'click .control-app-list': (event) ->
		$(event.currentTarget).closest(".app-sction-part-1").toggleClass("slds-is-open")

	'click .control-object-list': (event) ->
		$(event.currentTarget).closest(".app-sction-part-2").toggleClass("slds-is-open")

	'click .object-launcher-link,.app-launcher-link': (event, template) ->
		Modal.hide(template)

	'click .switchSpace': (event, template)->
		Modal.hide(template)
		switchToSpaceId = this._id
		Meteor.defer ()->
			Steedos.setSpaceId(switchToSpaceId)
			FlowRouter.go("/")

	
	'click .app-sction-part-1 .slds-section__content .app-launcher-link': (event)->
		appid = event.currentTarget.dataset.appid
		if appid && Creator.openApp
			Creator.openApp appid, event