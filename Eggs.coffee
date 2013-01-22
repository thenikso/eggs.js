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
# 		will also send validaton errors as an object having:
# 			* `error`: the error message returned by the `validate` method;
# 			* `attributes`: the invalid attributes object.
#
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

	# The model constructor will generate `attributes` and `attributeNames` method.
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

		# The attribute names list bus will receive arrays of strings containing
		# all the model's attribute names.
		attributeNamesBus = new Bacon.Bus
		unless attrsInitialValidationError
			attributeNamesProperty = attributeNamesBus.toProperty(_.keys(attrs))
		else
			attributeNamesProperty = attributeNamesBus.toProperty()

		# The validation process will push values or errors to `validAttributeBus`.
		setAttributesBus.map((value) -> 
				_.defaults({}, value, attrs)).onValue (attrObject) =>
			# Ignore update if equal to current state
			return if _.isEqual(attrObject, attrs)
			# Validation pass
			if options.shouldValidate and error = @validate?(attrObject)
				validAttributesBus.error({ error: error, attributes: attrObject })
			else
				attrsInitialValidationError = null
				if _.difference(_.keys(attrObject), _.keys(attrs)).length
					attributeNamesBus.push(_.keys(attrObject))
				validAttributesBus.push(_.clone(attrs = attrObject))

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
				if _.isArray(name)
					if value['unset']
						newAttrs = _.omit(attrs, name)
						if (_.difference(_.keys(attrs), _.keys(newAttrs)))
							attrs = newAttrs
							attributeNamesBus.push(_.keys(attrs))
							validAttributesBus.push(_.clone(attrs))
						return validAttributesProperty
				else if _.has(attrs, name)
					setObject = {}
					setObject[name] = value
					setAttributesBus.push(setObject)
					return validAttributesProperty
				else throw "Invalid attributes update: #{name}, #{value}"

		# Accessor to property names Bacon.Property
		@attributeNames = () ->
			attributeNamesProperty

		# Custom initialization
		@initialize.apply(@, arguments)

	# Initialize could be used by subclasses to add their own model initialization
	initialize: ->

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
			@attributes(result))

	# Initiates an AJAX request that sends the model's attributes to the server.
	# Returns a Bacon.EventStream derived from the AJAX request promise.
	# TODO options (updateModel, ...)
	save: ->
		Bacon.combineAsArray(@url(), @attributes())
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
			@attributes(result))



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



Eggs.ReplayBus = class ReplayBus extends Bacon.EventStream
	constructor: (@replayCount) ->
		sink = undefined
		unsubFuncs = []
		inputs = []
		ended = false
		guardedSink = (input) => (event) =>
			if (event.isEnd())
				remove(input, inputs)
				Bacon.noMore
			else
				sink event
		unsubAll = => 
			f() for f in unsubFuncs
			unsubFuncs = []
		subscribeAll = (newSink) =>
			sink = newSink
			unsubFuncs = []
			for input in cloneArray(inputs)
				unsubFuncs.push(input.subscribe(guardedSink(input)))
			unsubAll
		dispatcher = new Dispatcher(subscribeAll)
		subscribeThis = (sink) =>
			console.log "will subscribe #{sink}"
			dispatcher.subscribe(sink)
		super(subscribeThis)
		@plug = (inputStream) =>
			return if ended
			inputs.push(inputStream)
			if (sink?)
				unsubFuncs.push(inputStream.subscribe(guardedSink(inputStream)))
		@push = (value) =>
			sink next(value) if sink?
		@error = (error) =>
			sink new Error(error) if sink?
		@end = =>
			ended = true
			unsubAll()
			sink end() if sink?


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

