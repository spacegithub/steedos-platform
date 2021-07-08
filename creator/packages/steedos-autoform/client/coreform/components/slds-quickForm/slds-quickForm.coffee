Template.quickForm_slds.helpers
	isDisabled: (key)->
		object_name = Template.instance().data.atts.object_name
		#处理不能使用Creator.getObject 获取对象， 因为在client端， Creator.getObject 中的对象已被user permission 改写
		fields = Creator.Objects[object_name]?.fields
		return fields[key]?.disabled
	hasInlineHelpText: (key)->
		object_name = Template.instance().data.atts.object_name
		fields = Creator.getObject(object_name)?.fields
		return fields[key]?.inlineHelpText

	is_range: (key)->
		return Template.instance()?.data?.qfAutoFormContext.schema._schema[key]?.autoform?.is_range
	is_renge_end: (key)->
		return key?.endsWith("_endLine");

	schemaFields: ()->
		object_name = this.atts.object_name
		object = Creator.getObject(object_name)
		keys = []
		if object
			schemaInstance = this.qfAutoFormContext.schema
			schema = schemaInstance._schema

			firstLevelKeys = schemaInstance._firstLevelSchemaKeys
			permission_fields = this.qfAutoFormContext.fields || firstLevelKeys

			unless permission_fields
				permission_fields = []

			_.each schema, (value, key) ->
				if (_.indexOf firstLevelKeys, key) > -1
					if !value.autoform?.omit
						keys.push key

			if keys.length == 1
				finalFields =
					grouplessFields: [keys]
				return finalFields

			hiddenFields = Creator.getHiddenFields(schema)
			disabledFields = Creator.getDisabledFields(schema)

			fieldGroups = []
			fieldsForGroup = []
			isSingle = Session.get "cmEditSingleField"

			grouplessFields = []
			grouplessFields = Creator.getFieldsWithNoGroup(schema)
			grouplessFields = Creator.getFieldsInFirstLevel(firstLevelKeys, grouplessFields)
			if permission_fields
				grouplessFields = _.intersection(permission_fields, grouplessFields)
			grouplessFields = Creator.getFieldsWithoutOmit(schema, grouplessFields)
			grouplessFields = Creator.getFieldsForReorder(schema, grouplessFields, isSingle)

			fieldGroupNames = Creator.getSortedFieldGroupNames(schema)
			_.each fieldGroupNames, (fieldGroupName) ->
				fieldsForGroup = Creator.getFieldsForGroup(schema, fieldGroupName)
				fieldsForGroup = Creator.getFieldsInFirstLevel(firstLevelKeys, fieldsForGroup)
				if permission_fields
					fieldsForGroup = _.intersection(permission_fields, fieldsForGroup)
				fieldsForGroup = Creator.getFieldsWithoutOmit(schema, fieldsForGroup)
				fieldsForGroup = Creator.getFieldsForReorder(schema, fieldsForGroup, isSingle)
				fieldGroups.push
					name: fieldGroupName
					fields: fieldsForGroup

			finalFields =
				grouplessFields: grouplessFields
				groupFields: fieldGroups
				hiddenFields: hiddenFields
				disabledFields: disabledFields
			return finalFields

	horizontal: ()->
		return Template.instance().data.atts.horizontal

	is_range_fields: (fields)->
		if fields?.length > 0 && fields[0]
			return Template.instance()?.data?.qfAutoFormContext.schema._schema[fields[0]]?.autoform?.is_range

	has_wide_field: (fields)->
		if fields?.length > 0 && fields[0]
			return Template.instance()?.data?.qfAutoFormContext.schema._schema[fields[0]]?.autoform?.is_wide

	autoExpandGroup: ()->
		return Template.instance().data.atts.autoExpandGroup || false

Template.quickForm_slds.events
	'click .group-section-control': (event, template) ->
		event.preventDefault()
		event.stopPropagation()
		$(event.currentTarget).closest('.group-section').toggleClass('slds-is-open')

Template.quickForm_slds.onRendered ->
	self = this
	self.$(".has-inline-text").each ->
		id = "info_" + $(".control-label", $(this)).attr("for")
		html = """
				<span class="help-info" id="#{id}">
					<i class="ion ion-information-circled"></i>
				</span>
			"""
		$(".control-label", $(this)).append(html)


	self.$(".info-popover").each ->
		_id = $("~ .form-group .help-info", $(this)).attr("id");
		$(this).dxPopover
			target: "#" + _id,
			showEvent: "mouseenter",
			hideEvent: "mouseleave",
			position: "top",
			width: 300,
			animation: {
				show: {
					type: "pop",
					from: {
						scale: 0
					},
					to: {
						scale: 1
					}
				},
				hide: {
					type: "fade",
					from: 1,
					to: 0
				}
			}

Template.range_field.helpers
	startName: ()->
		return this.toString()
	endName: ()->
		return this.toString() + '_endLine'