Template.creator_app_home.onRendered ()->
	this.autorun ->
		isBootstrapLoaded = Creator.bootstrapLoaded.get()
		appId = Session.get('app_id')
		if isBootstrapLoaded && appId
			dashboard = Creator.getAppDashboard()
			unless dashboard
				dashboard = Creator.getAppDashboardComponent()
			if dashboard and !Steedos.isMobile()
				FlowRouter.go "/app/#{appId}/home"
			else
				first_app_obj = _.first(Creator.getAppObjectNames(appId))
				if first_app_obj
					objectHomeComponent = Session.get("object_home_component")
					if objectHomeComponent
						FlowRouter.go "/app/" + appId + "/" + first_app_obj
					else
						list_view = Creator.getListView(first_app_obj, null)
						list_view_id = list_view?._id
						FlowRouter.go Creator.getListViewRelativeUrl(first_app_obj, appId, list_view_id)