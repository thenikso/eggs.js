# Eggs 0.0.1

Eggs = @Eggs = {}

# Eggs.Model
# ----------

# An `Eggs.Model` lets you manage data and synchronize it with the server.
# To specify a new model, the class should be extended using either coffee 
# script's `extend` or `Eggs.Model.extend`. Methods that may be extended are:
# 	- `initialize` will be called when a new isntance of the model is created;
# 	- `validate` will be called with an object of attributes that should be
# 		validated. Returns an error (usually a string) or nothing if the validation
# 		was successful.
#
# Once extended, the new model class can be instantiated to represent an entry.
# The constructor accepts the initial *attributes* for the new model instance
# and *options*. Initial attributes will be passed through the validation process
# if any. Available options are:
# 	- `shouldValidate` defaults to `true` and indicates if the model isntance should
# 		be validated.
#
# Instance members:
# 	- `attributes` is a Bacon.Property that pushes an object containing all 
# 		the model instance attributes after validation. 
# 		A validation error object is pushed if the validation process failed.
# 		The error object contains:
# 			* `error`: the error message returned by the `validate` method
# 			* `attributes`: the invalid attributes objec
# 		`attributes` is decorated with:
# 			* `set`: a method that accepts an object to update the model instance
# 				attributes. This method will create new properties if needed.
# 	- `properties` is an object that associate property names with Bacon.Property.
# 		If, for example, the model has a `myProperty` property, one can access it 
# 		via `myModel.properties.myProperty`.
# 		Each property object is decorated with:
# 			* `set`: a method that can be used to set the signle property
# 	- `propertyNames` is a Bacon.Property that pushes an array with all the 
# 		available properties in the model instance.
#
# Example Usage:
# 	class MyModel extends Eggs.Model
# 		defaults: { myField: 'myFieldDefaultValue' }
# 		validate: (attributes) -> "too short!" if attributes.myField.length < 3
# 	myModel = new MyModel({ myOtherField: 2 })
# 	myModel.attributes.onValue (value) -> console.log(value)
Eggs.Model = class Model
	constructor: (attributes, options) ->
		options = _.defaults({
			shouldValidate: true
		}, options)

		# Get model instance attributes. `attrs` will keep the current attributes
		# object within this method.
		attrs = attributes or {}
		attrs = _.defaults({}, attrs, defaults) if defaults = _.result(@, 'defaults')

		# Initial validation. Attributes and properties will not have an initial value
		# if attrs are invalid.
		attrsInitialValidationError = options.shouldValidate and @validate?(attrs)

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
		propertyNamesBus = new Bacon.Bus

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
		generatedPropertiesBusses = propertyNamesBus.map (propertyNames) ->
			makeProperty(propertyName) for propertyName in propertyNames
			propertiesBusses

		# The accessible property names list will push after the propertyes 
		# have been created.
		@propertyNames = generatedPropertiesBusses.map((busses) -> _.keys(busses))
		unless attrsInitialValidationError
			@propertyNames = @propertyNames.toProperty(_.keys(attrs))
		else
			@propertyNames = @propertyNames.toProperty()

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
			if options.shouldValidate and error = @validate?(attrObject)
				validAttributesBus.error(error)
			else
				if _.difference(_.keys(attrObject), _.keys(attrs)).length
					attrs = attrObject
					propertyNamesBus.push(_.keys(attrs))
				validAttributesBus.push(attrs = attrObject)

		# This will start the reaction that eventually generates a template
		# used to combine single propertyes and validate them.
		propertyNamesBus.push(_.keys(attrs))

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

