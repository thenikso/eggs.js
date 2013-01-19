# Eggs 0.0.1

Eggs = @Eggs = {}

# Eggs.Model
# ----------

# An `Eggs.Model` lets you manage data and synchronize it with the server.
# Options:
#
# Properties:
# 	- `attributes` push and object containing all the model instance attributes
# 		after validation. An validation error object is pushed if the validation 
# 		process failed. The error object contains an `error` and an `attributes`
# 		field with the error message returned by the validation process and the
# 		invalid attributes object.
#
# Usage:
# 	class MyModel extends Eggs.Model
# 		defaults: { myField: 'myFieldDefaultValue' }
Eggs.Model = class Model
	constructor: (attributes, options) ->
		options = _.defaults({
			validate: true
		}, options)

		# Get model instance attributes. `attrs` will keep the current attributes
		# object within this method.
		attrs = attributes or {}
		attrs = _.defaults({}, attrs, defaults) if defaults = _.result(@, 'defaults')

		# Initial validation. Attributes and properties will not have an initial value
		# if attrs are invalid.
		attrsInitialValidationError = options.validate and @validate?(attrs)

		# The bus and relative property that will send validated attributes
		# and validation errors.
		validAttributesBus = new Bacon.Bus
		unless attrsInitialValidationError
			@attributes = validAttributesBus.toProperty(attrs)
		else
			@attributes = validAttributesBus.toProperty()

		# `attributes` will be decorated with a `set` method that will trigger
		# the validation process and eventually push new validated attributes.
		setAttributesBus = new Bacon.Bus
		@attributes.set = (value) -> setAttributesBus.push(value)

		# The properties name list bus will receive arrays of the property names
		propertyNamesListBus = new Bacon.Bus

		# Create properties. Properties are derived from validated attributes and
		# each property will be decorated with a `set` method like `attributes`.
		@properties = {}
		propertiesBusses = {}
		makeProperty = (propertyName) =>
			unless @properties[propertyName]
				@properties[propertyName] = @attributes.map(".#{propertyName}")
				setPropertyBus = new Bacon.Bus
				@properties[propertyName].set = (value) -> setPropertyBus.push(value)
				propertiesBusses[propertyName] = setPropertyBus.toProperty(attrs[propertyName])

		# Initial properties generation in case of valid attributes
		makeProperty(propertyName) for propertyName of attrs unless attrsInitialValidationError
		
		# Generates new properties when added to property names
		generatedPropertiesBusses = propertyNamesListBus.map (propertyNames) ->
			makeProperty(propertyName) for propertyName in propertyNames
			propertiesBusses

		# The accessible property names list will push after the propertyes 
		# have been created.
		@propertyNamesList = generatedPropertiesBusses.map((busses) -> _.keys(busses))
		unless attrsInitialValidationError
			@propertyNamesList = @propertyNamesList.toProperty(_.keys(attrs))
		else
			@propertyNamesList = @propertyNamesList.toProperty()

		# The validation process starts by combining all the unchecked properties
		# and pass them throught the validate method. Reflects on attributes.
		Bacon.mergeAll([
			setAttributesBus.map (value) -> 
				_.defaults({}, value, attrs)
			generatedPropertiesBusses.flatMapLatest(Bacon.combineTemplate)
		]).onValue (attrObject) =>
			# Ignore update if equal to current state
			return if _.isEqual(attrObject, attrs)
			# Validation pass
			if options.validate and error = @validate?(attrObject)
				validAttributesBus.error(error)
			else
				if _.difference(_.keys(attrObject), _.keys(attrs)).length
					attrs = attrObject
					propertyNamesListBus.push(_.keys(attrs))
				validAttributesBus.push(attrs = attrObject)

		# Setting 
		propertyNamesListBus.push(_.keys(attrs))

		# Custom initialization
		@initialize.apply(@, arguments)

	initialize: () ->


Eggs.model = (extension) -> 
	parent = Model
	if extension and _.has(extension, 'constructor')
		child = extension.constructor
	else
		child = () -> parent.apply(@, arguments)

	class Surrogate
		constructor: () -> @constructor = child	
	Surrogate.prototype = parent.prototype
	child.prototype = new Surrogate

	_.extend(child.prototype, extension) if extension

	child.__super__ = parent.prototype
	child






routeStripper = /^[#\/]|\s+$/g

Eggs.currentLocation = (() ->
	location = window?.location
	hasPushState = location?.history?.pushState
	hasHashChange = 'onhashchange' of window

	getHash = () ->
		match = location.href.match /#(.*)$/
		if match then match[1] else ''

	getFragment = (fragment) ->
		unless fragment
			if hasPushState or not hasHashChange
				fragment = location.pathname
			else
				fragment = getHash()
		fragment.replace(routeStripper, '')

	if hasPushState
		windowLocationStream = Bacon.fromEventTarget(window, 'popstate')
	else if hasHashChange
		windowLocationStream = Bacon.fromEventTarget(window, 'hashchange')
	else
		windowLocationStream = Bacon.interval(100)

	windowLocationStream
		.map(() -> 
			getFragment())
		.skipDuplicates()
		.toProperty(getFragment())
	)()

# Routing
optionalParam = /\((.*?)\)/g
namedParam    = /(\(\?)?:\w+/g
splatParam    = /\*\w+/g
escapeRegExp  = /[\-{}\[\]+?.,\\\^$|#\s]/g

Eggs.route = (route) ->
	# Get the RegExp for the route
	unless _.isRegExp(route)
		route = route
			.replace(escapeRegExp, '\\$&')
			.replace(optionalParam, '(?:$1)?')
			.replace(namedParam, (match, optional) -> 
				if optional then match else '([^\/]+)')
			.replace(splatParam, '(.*?)')
		route = new RegExp('^' + route + '$')
	
	Eggs
		.currentLocation
		.filter((location) ->
			route.test(location))
		.map((location) ->
			route.exec(location).slice(1))

