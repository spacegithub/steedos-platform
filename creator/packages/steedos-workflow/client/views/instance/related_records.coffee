Template.related_records.helpers RelatedRecords.helpers

Template.related_records.events
	'click .ins-related-records': (event, template)->
		creatorService = Meteor.settings.public.webservices?.creator?.url
		ins = WorkflowManager.getInstance()
		if creatorService && ins
			objcetName = ins.record_ids[0].o
			id = ins.record_ids[0].ids[0]
			uobj = {}
			uobj["X-User-Id"] = Meteor.userId()
			uobj["X-Auth-Token"] = Accounts._storedLoginToken()
			redirectUrl = creatorService + "app/-/#{objcetName}/view/#{id}?" + $.param(uobj)
			Steedos.openWindow redirectUrl
