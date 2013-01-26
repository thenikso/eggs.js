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
# Instance overridable methods:
# 	- `idAttribute` is the name of the attribute used to compute `id` and 
# 		`url` properties values.
#
# Instance methods:
# 	- `attributes` is a multi-purpose method that executes various model's
# 		attributes related operation depending on input parameters:
# 		- *no parameters*: **gets** a Bacon.Property with model's attributes object;
# 		- *name*: **gets**, if possible, a Bacon.Property for the single
# 			attribute with the given name;
# 		- *object*: **set** attributes by **add**ing or modifying the current ones;
# 			if an attribute present in the model is not specified by the given object,
# 			it will maintain it's current value. This will trigger the validation;
# 		- *name string, value*: will **set** the single attribute with the given 
# 			value if possible; this will trigger the validation process;
# 		- *names array, options*: the options object can contain a boolean 
# 			`unset` key, in which case attributes with the given names will be
# 			**removed** from the model.
# 		Both getter variants (no parameter, single string parameter) Bacon.Property
# 		will also send validaton errors.
#
# Instance utility methods (also overridable):
# 	- `attributeNames` returns a Bacon.Property that pushes an array with all the 
# 		current valid attribute names in the model instance.
#
# Example Usage:
# 	class MyModel extends Eggs.Model
# 		defaults: { myField: 'myFieldDefaultValue' }
# 		validate: (attributes) -> "too short!" if attributes.myField.length < 3
# 	myModel = new MyModel({ myOtherField: 2 })
# 	myModel.attributes().onValue (value) -> console.log(value)
Eggs.Model = class Model

	# The default attribute name for linking the model with the database.
	# MongoDB and CouchDB users may want to set this to `"_id"`
	idAttribute: 'id'

	# Initialize could be used by subclasses to add their own model initialization
	initialize: ->

	# Parse is used to convert a server response into the object to be
	# set as attributes for the model instance.
	# It's a plain function returning an object that will be passed to
	# `attributes` from the default `fetch` implementation.
	parse: (response) -> 
		response

	# The model constructor will generate `attributes` method.
	constructor: (attributes, options) ->
		options = _.defaults({}, options, {
			shouldValidate: true
		})

		# Get model instance attributes. `attrs` will keep the current attributes
		# object within this method.
		attrs = attributes or {}
		attrs = _.defaults({}, attrs, defaults) if defaults = _.result(@, 'defaults')

		# Initial validation. Attributes will not have an initial value
		# if `attrs` are invalid.
		attrsInitialValidationError = options.shouldValidate and @validate?(_.clone(attrs))

		# The bus and relative Property that will send validated attributes
		# and validation errors.
		validAttributesBus = new Bacon.Bus
		unless attrsInitialValidationError
			validAttributesProperty = validAttributesBus.toProperty(_.clone(attrs))
		else
			validAttributesProperty = validAttributesBus.toProperty()
		validSingleAttributes = {}

		# Subscribe on an empty function to activate the property so that it will
		# always be current.
		validAttributesProperty.onValue ->

		# The bus used to push un-validated attributes. This bus will be used to
		# trigger the validation process.
		setAttributesBus = new Bacon.Bus

		# The validation process will push values or errors to `validAttributeBus`.
		setAttributesBus.map((value) -> 
				_.defaults({}, value, attrs)).onValue (attrObject) =>
			# Ignore update if equal to current state
			return if _.isEqual(attrObject, attrs)
			# Validation pass
			if options.shouldValidate and error = @validate?(attrObject)
				validAttributesBus.error(error)
			else
				attrsInitialValidationError = null
				attrs = _.clone(attrObject)
				validAttributesBus.push(_.clone(attrs))

		# The main accessor to model attributes.
		@attributes = (name, value) ->
			return validAttributesProperty if arguments.length == 0
			if arguments.length == 1
				if _.isObject(name)
					setAttributesBus.push(name)
					return validAttributesProperty
				# TODO array case to merge attributes changes
				else if _.has(attrs, name)
					unless validAttributesProperty[name]
						unless attrsInitialValidationError
							validAttributesProperty[name] = validAttributesBus.map(".#{name}").toProperty(attrs[name])
						else
							validAttributesProperty[name] = validAttributesBus.map(".#{name}").toProperty()
					return validAttributesProperty[name]	
				else throw "Invalid attributes accessor: #{name}"
			else
				# TODO: object + options case (options: reset, merge, ...)
				if _.isArray(name)
					if value['unset']
						newAttrs = _.omit(attrs, name)
						if (_.difference(_.keys(attrs), _.keys(newAttrs)))
							attrs = newAttrs
							validAttributesBus.push(_.clone(attrs))
						return validAttributesProperty
				else if _.has(attrs, name)
					setObject = {}
					setObject[name] = value
					setAttributesBus.push(setObject)
					return validAttributesProperty
				else throw "Invalid attributes update: #{name}, #{value}"

		# Custom initialization
		@initialize.apply(@, arguments)

	# Initiates an AJAX request to fetch the model's data form the server.
	# Returns a Bacon.EventStream that will send the updated attributes once
	# they have been set to the model.
	fetch: ->
		@url()
		.take(1)
		.flatMap((url) ->
			Bacon.fromPromise $.ajax
				type: 'GET'
				dataType: 'json'
				url: url)
		.flatMap((result) =>
			@attributes @parse(result))

	# Initiates an AJAX request that sends the model's attributes to the server.
	# Returns a Bacon.EventStream derived from the AJAX request promise.
	# TODO options (updateModel, ...)
	save: ->
		Bacon.combineAsArray(@url(), @toJSON())
		.take(1)
		.flatMap((info) =>
			[url, attributes] = info
			Bacon.fromPromise $.ajax
				type: if attributes[@idAttribute] then 'PUT' else 'POST'
				dataType: 'json'
				processData: false
				url: url
				data: attributes)
		.flatMap((result) =>
			@attributes @parse(result))

	# Destroy the model instance on the server if it was present.
	# Returns a Bacon.EvnetStream that will push a single value returned from
	# the server or `null` if no server activity was initiated.
	# TODO remove from collection
	destroy: ->
		Bacon.combineAsArray(@url(), @id())
		.take(1)
		.flatMap((info) ->
			[url, id] = info
			if id?
				Bacon.fromPromise $.ajax
					type: 'DELETE'
					dataType: 'json'
					processData: false
					url: url
			else
				Bacon.once(null))

	attributeNames: ->
		@attributes().map _.keys

	# Unset the given attributes in the model. The parameter can either be a string
	# with the name of the attribute to unset, or an array of names.
	unset: (attrNames) ->
		attrNames = [attrNames] unless _.isArray(attrNames)
		@attributes(attrNames, { unset: true })

	# Returns a Bacon.Property pushing the id of the model or null if the model 
	# is new. This method uses `idAttribute` to determine which attribute is the id.
	id: -> 
		@_id or= @attributes().map (attr) =>
			attr[@idAttribute]

	# Returns a Bacon.Property that updates with the URL for synching the model.
	# This methos uses `urlRoot` to compute the URL.
	url: ->
		@_url or= @id().map (id) =>
			base = _.result(@, 'urlRoot') or throw new Error("Expecting `urlRoot` to be defined")
			base = base.substring(0, base.length - 1) if base.charAt(base.length - 1) is '/'
			return "#{base}/#{encodeURIComponent(id)}" if id
			base

	# Returns a Bacon.Property with the JSON reppresentation of the model's 
	# attributes. By deafult, this function just returns `attributes()`.
	toJSON: ->
		@attributes()





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

