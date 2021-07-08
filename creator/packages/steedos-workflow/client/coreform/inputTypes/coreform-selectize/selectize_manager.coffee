getLabel = (code, doc, formula)->
	if code.indexOf('.') > -1
		code = code.split('.')[1]
	try
		SelectizeManagerDoc = {}
		SelectizeManagerDoc[code] = _.clone(doc) || {}
		label = eval(formula)
		return label
	catch e
		console.log("公式["+formula+"]执行异常：" + e.message);

getElementData = ($element)->
	if $element && $element.length > 0
		return $element[0].odata

valOutformat = (val)->
	if val
		_.each _.keys(val), (key)->
			if key.indexOf('.') > -1 || key.startsWith('$')
				delete val[key]
	return val || {}


@SelectizeManager =
	formatLabel: (code, data, formula)->
		formula = '{_formatLabel} = ' +  formula
		formula = Form_formula.prependPrefixForFormula('SelectizeManagerDoc', formula)
		_.each data, (item)->
			label = getLabel(code, item, formula)
			item['@label'] = label
		return data;
	valueOutformat: (val)->
		vals = []
		if _.isArray(val)
			_.each val, (item)->
				vals.push valOutformat(item)
			return vals
		else
			return valOutformat(val)
	getCreatorService: (data)->
		return data.url || Meteor.settings.public?.webservices?.creator?.url
	getService: (data)->
		spaceId = Steedos.getSpaceId()
		if data.url
			if /^http(s?):\/\//.test(data.url)
				return data.url
			else
				return Steedos.absoluteUrl(data.url)
		creatorService = SelectizeManager.getCreatorService(data)
		return Meteor.absoluteUrl("api/odata/v4/#{spaceId}", {rootUrl :creatorService})
	getHeaders: ($element)->
		elementData = getElementData($element)
		return elementData?.headers || {
			'X-Auth-Token': Accounts._storedLoginToken(),
			'X-User-Id': Meteor.userId()
		}
	getTop: ($element)->
		elementData = getElementData($element)
		return elementData?.top || 10
	onFocus: ()->
		elementData = getElementData(this.$input)
		if _.isFunction(elementData?.onFocus)
			elementData.onFocus()
	onBlur: ()->
		elementData = getElementData(this.$input)
		if _.isFunction(elementData?.onBlur)
			elementData.onBlur()
	onItemAdd: (value, $item)->
		elementData = getElementData(this.$input)
		if _.isFunction(elementData?.onItemAdd)
			elementData.onItemAdd(value, $item)
	onItemRemove: (value)->
		elementData = getElementData(this.$input)
		if _.isFunction(elementData?.onItemRemove)
			elementData.onItemRemove(value)
	onChange: (value)->
		elementData = getElementData(this.$input)
		if _.isFunction(elementData?.onChange)
			elementData.onChange(value)
	onClear: ()->
		elementData = getElementData(this.$input)
		if _.isFunction(elementData?.onClear)
			elementData.onClear()
	onDelete: (values)->
		elementData = getElementData(this.$input)
		if _.isFunction(elementData?.onDelete)
			elementData.onDelete(values)
	onOptionAdd: (value, data)->
		elementData = getElementData(this.$input)
		if _.isFunction(elementData?.onOptionAdd)
			elementData.onOptionAdd(value, data)
	onOptionRemove: (value)->
		elementData = getElementData(this.$input)
		if _.isFunction(elementData?.onOptionRemove)
			elementData.onOptionRemove(value)
	onDropdownOpen: ($dropdown)->
		elementData = getElementData(this.$input)
		if _.isFunction(elementData?.onDropdownOpen)
			elementData.onDropdownOpen($dropdown)
	onDropdownClose: ($dropdown)->
		elementData = getElementData(this.$input)
		if _.isFunction(elementData?.onDropdownClose)
			elementData.onDropdownClose($dropdown)
	onType: (str)->
		elementData = getElementData(this.$input)
		if _.isFunction(elementData?.onType)
			elementData.onType(str)
	onLoad: (data)->
		elementData = getElementData(this.$input)
		if _.isFunction(elementData?.onLoad)
			elementData.onLoad(data)
#	dataFunc: ($element, service, objectName, options, cb)->
#		OdataClient = require('odata-client');
#		q = OdataClient({
#			service: service,
#			resources: objectName,
#			headers: SelectizeManager.getHeaders($element)
#		}).top(SelectizeManager.getTop($element))
#		query = options.query?.trim()
#		search_field = options.search_field?.trim()
#		if query && search_field
#			query = options.query.replace(new RegExp('\''), '')
#			_.each query.split(' '), (text)->
#				if !_.isEmpty(text)
#					ex = null
#					_.each search_field.split(','), (field)->
#						if !_.isEmpty(field)
#							if !ex
#								ex = OdataClient.expression("contains(tolower(#{field}), '#{text}')")
#							else
#								ex = ex.or("contains(tolower(#{field}), '#{text}')")
#					if !_.isEmpty(ex)
#						q.and(ex)
#		if options.filters
#			q.and(options.filters)
#		elementData = getElementData($element)
#		if _.isFunction(elementData?.beforeGet)
#			elementData.beforeGet(q)
#
#		q.get().then (response)->
#			data = SelectizeManager.formatLabel(options.code, JSON.parse(response.body).value, options.formula);
#			if _.isEmpty($element[0].selectize.getValue())
#				$element[0].selectize.clearOptions()
#			cb(data)
	dataFunc: ($element, service, objectName, options, cb)->

		query = options.query?.trim()
		search_field = options.search_field?.trim()
		filtersStr = "";

		if query && search_field
			query = options.query.replace(new RegExp('\''), '')
			_.each query.split(' '), (text)->
				if !_.isEmpty(text)
					filtersOrStr = "";
					_.each search_field.split(','), (field)->
						if !_.isEmpty(field)
							if _.isEmpty(filtersOrStr)
								filtersOrStr = "(contains(tolower(#{field}), '#{encodeURIComponent(Creator.convertSpecialCharacter(text))}'))"
							else
								filtersOrStr = "#{filtersOrStr} or " + "(contains(tolower(#{field}), '#{encodeURIComponent(Creator.convertSpecialCharacter(text))}'))"

					if !_.isEmpty(filtersOrStr)
						if _.isEmpty(filtersStr)
							filtersStr = filtersOrStr
						else
							filtersStr = "#{filtersStr} and #{filtersOrStr}"
		if options.filters
			if filtersStr
				filtersStr = "(#{options.filters}) and (#{filtersStr})"
			else
				filtersStr = "(#{options.filters})"
		elementData = getElementData($element)
		if _.isFunction(elementData?.beforeGet)
			elementData.beforeGet(filtersStr)
		request_data = {}
		if filtersStr
			request_data.$filter = filtersStr
		$.ajax
			type: "get"
			url: service
			data: request_data
			dataType: "json"
			contentType: "application/json"
			beforeSend: (request) ->
				request.setRequestHeader('X-User-Id', Meteor.userId())
				request.setRequestHeader('X-Auth-Token', Accounts._storedLoginToken())
				request.setRequestHeader('X-Space-Id', Steedos.spaceId())
			success: (data) ->
				result = SelectizeManager.formatLabel(options.code, data.value, options.formula);
				if _.isEmpty($element[0].selectize.getValue())
					$element[0].selectize.clearOptions()
				cb(result)
			error: (jqXHR, textStatus, errorThrown) ->
				error = jqXHR.responseJSON?.error
				if error?.reason
					toastr?.error?(TAPi18n.__(error.reason))
				else if error?.message
					toastr.error(t(error?.message))
				else
					toastr?.error?("未找到记录")
