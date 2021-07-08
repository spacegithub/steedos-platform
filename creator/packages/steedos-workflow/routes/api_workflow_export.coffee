Meteor.startup ->
	WebApp.connectHandlers.use "/api/workflow/export/instances", (req, res, next) ->
		try
			current_user_info = uuflowManager.check_authorization(req)

			query = req.query
			space_id = query.space_id
			flow_id = query.flow_id
			type = parseInt(query.type)
			timezoneoffset = parseInt(query.timezoneoffset)

			flow = db.flows.findOne({ _id: flow_id }, { fields: { form: 1 } })
			form = db.forms.findOne({ _id: flow.form }, { fields: { name: 1, 'current.fields': 1 } })

			form_name = form.name
			fields = form.current.fields
			table_fields = new Array
			_.each form.current.fields, (field) ->
				if field.type is "table"
					table_fields.push(field)

			ins_to_xls = new Array
			start_date = null
			end_date = null
			now = new Date
			selector = { space: space_id, flow: flow_id }
			selector.state = {$in: ["pending", "completed"]}
			uid = current_user_info._id
			space = db.spaces.findOne(space_id)
			if !space
				selector.state = "none"

			if !space.admins.includes(uid)
				flow_ids = WorkflowManager.getMyAdminOrMonitorFlows(space_id, uid)
				if !flow_ids.includes(selector.flow)
					selector.$or = [{submitter: uid}, {applicant: uid}, {inbox_users: uid}, {outbox_users: uid}]

			# 0-本月
			if type is 0
				start_date = new Date(now.getFullYear(), now.getMonth(), 1)
				selector.submit_date = { $gte: start_date }
				ins_to_xls = db.instances.find(selector, {
					sort: { submit_date: 1 }
				}).fetch()
			# 1-上月
			else if type is 1
				last_month_date = new Date(new Date(now.getFullYear(), now.getMonth(), 1) - 1000 * 60 * 60 * 24)
				start_date = new Date(last_month_date.getFullYear(), last_month_date.getMonth(), 1)
				end_date = new Date(now.getFullYear(), now.getMonth(), 1)
				selector.submit_date = { $gte: start_date, $lte: end_date }
				ins_to_xls = db.instances.find(selector, {
					sort: { submit_date: 1 }
				}).fetch()
			# 2-整个年度
			else if type is 2
				start_date = new Date(now.getFullYear(), 0, 1)
				selector.submit_date = { $gte: start_date }
				ins_to_xls = db.instances.find(selector, {
					sort: { submit_date: 1 }
				}).fetch()
			# 3-所有
			else if type is 3
				ins_to_xls = db.instances.find(selector, {
					sort: { submit_date: 1 }
				}).fetch()

			ejs = require('ejs')
			str = Assets.getText('server/ejs/export_instances.ejs')

			# 检测是否有语法错误
			ejsLint = require('ejs-lint')
			error_obj = ejsLint.lint(str, {})
			if error_obj
				console.error "===/api/workflow/export:"
				console.error error_obj

			template = ejs.compile(str)

			lang = 'en'
			if current_user_info.locale is 'zh-cn'
				lang = 'zh-CN'
			
			utcOffset = timezoneoffset / -60
			
			formatDate = (date, formater) ->
				return moment(date).utcOffset(utcOffset).format(formater)

			ret = template({
				lang: lang,
				formatDate: formatDate,
				form_name: form_name,
				fields: fields,
				table_fields: table_fields,
				ins_to_xls: ins_to_xls
			})

			fileName = "SteedOSWorkflow_" + moment().format('YYYYMMDDHHmm') + ".xls"
			res.setHeader("Content-type", "application/octet-stream")
			res.setHeader("Content-Disposition", "attachment;filename=" + encodeURI(fileName))
			res.end(ret)
		catch e
			console.error e.stack
			res.end(e.message)