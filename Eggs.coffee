# Eggs 0.0.1

isHash = (obj) -> (obj instanceof Object) and not (obj instanceof Array) and (typeof obj isnt 'array')

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
# 	- `attributes` returns a Bacon.Property of valid attributes in the model.
# 		Validation errors are sent through. It accepts parameters to get specific
# 		attributes:
# 		- *string*: returns a Bacon.Property sending values for the attribute with
# 			the specified name;
# 		- *array of strings*: returns a Bacon.Property sending collected values
# 			of all attributes specified every time one of those attribute changes.
# 	- `set` modify attributes. Attributes will be validated if needed and the
# 		actual change will happen only if the set attribute is valid. `set` accepts
# 		different inputs:
# 		- *object, options*: set attributes by adding or modifying the current ones;
# 		- *name string, value*: will set or add the single attribute with the given 
# 			value if possible;
# 		- *names array, options*: apply options derived actions to attributes in the
# 			array.
# 		Options are:
# 		- `reset`: defualt to false, if true will remove all attributes before 
# 			setting the new ones. If false, setted attributes will be merged with 
# 			existing ones;
# 		- `unset`: default to false, if true will remove the specified attributes
# 			instead of setting them.
# 		Returns `attributes`.
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
	# `set` from the default `fetch` implementation.
	parse: (response) -> 
		response

	# `defaults` can be defined as an object that contains default attributes
	# that will be used when creating a new model.

	# `validate` can be defined to be a function receiving attributes and 
	# returning a falsy value if the attributes are valid. If the function
	# returns something it will be treated as a validation error value.

	# The model constructor will generate `attributes` method. It will also assing
	# a client id `cid` to the model.
	constructor: (attrs, options) ->
		options = _.defaults {}, options, 
			shouldValidate: yes
			collection: null
		attributesAreValid = not options.shouldValidate

		# Generate a unique client id that wil be used by collections for 
		# unsaved models
		@cid = _.uniqueId('c')

		# The collection that this model is in.
		@collection = options.collection

		# The bus and relative Property that will send validated attributes
		# and validation errors.
		attributes = null
		attributesBus = new Bacon.Bus
		attributesProperty = attributesBus.toProperty()

		# Subscribe on an empty function to activate the property so that it will
		# always be current.
		attributesProperty.onValue ->

		# The main accessor to model attributes.
		@attributes = (names) ->
			return attributesProperty if arguments.length == 0
			return attributesProperty.map(".#{names}") if _.isString(names)
			if _.isArray(names)
				return attributesProperty.map (attributes) ->
					(attributes[n] for n in names)
			throw new Error("Invalid parameter for `set` method: #{names}")

		# Setting model's attributes
		@set = (obj, opts) ->
			unless arguments.length > 1 or isHash(obj)
				throw new Error("Invalid parameter for `set` method: #{obj}")
			opts ?= {}
			if opts.unset
				if _.isString(obj) then obj = [obj]
				else if isHash(obj) then obj = _.keys(obj)
				newAttributes = _.omit(attributes, obj)
				if _.difference(_.keys(attributes), _.keys(newAttributes))
					attributes = newAttributes
					attributesBus.push(_.clone(attributes))
				return attributesProperty
			if _.isString(obj)
				o = {}
				o[obj] = opts
				obj = o
				opts = {}
			unless opts.reset
				obj = _.defaults({}, obj, attributes)
			# Validation
			unless _.isEqual(obj, attributes)
				if options.shouldValidate and error = @validate?(obj)
					attributesBus.error(error)
					attributesBus.push({}) unless attributesAreValid
				else
					attributesAreValid = yes
					attributes = _.clone(obj)
					attributesBus.push(_.clone(attributes))
			attributesProperty

		# Will indicate if the current set of attributes is valid.
		@valid = ->
			@_valid or= attributesBus.map(yes).toProperty(attributesAreValid).skipDuplicates()

		# Initialize the model attributes
		attrs = _.defaults({}, attrs, defaults) if defaults = _.result(@, 'defaults')
		@set(attrs or {})

		# Custom initialization
		@initialize.apply(@, arguments)

	# Initiates an AJAX request to fetch the model's data form the server.
	# Returns a Bacon.Property that will send the updated attributes once
	# they have been set to the model.
	fetch: ->
		fetch = @url()
			.take(1)
			.flatMapLatest((url) ->
				Bacon.fromPromise $.ajax
					type: 'GET'
					dataType: 'json'
					url: url)
			.flatMapLatest((result) =>
				@set @parse(result))
			.take(1).toProperty()

		# Activate the fetch reaction
		fetch.onValue ->
		fetch

	# Initiates an AJAX request that sends the model's attributes to the server.
	# Returns a Bacon.Property derived from the AJAX request promise.
	# TODO options (updateModel, wait, ...)
	save: ->
		save = Bacon.combineAsArray(@url(), @toJSON())
			.take(1)
			.flatMapLatest((info) =>
				[url, attributes] = info
				Bacon.fromPromise $.ajax
					type: if attributes[@idAttribute] then 'PUT' else 'POST'
					dataType: 'json'
					processData: false
					url: url
					data: attributes)
			.flatMapLatest((result) =>
				@set @parse(result))
			.take(1).toProperty()

		# Activate the save operation
		save.onValue ->
		save

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

	# A Bacon.Property sending array of strings with the names of current valid 
	# model attributes.
	attributeNames: ->
		@_attributeNames or= @attributes().map(_.keys)

	# Unset the given attributes in the model. The parameter can either be a string
	# with the name of the attribute to unset, or an array of names.
	unset: (attrNames) ->
		@set(attrNames, { unset: true })

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


# Eggs.Collection
# ---------------

# An `Eggs.Collection` groups together multiple model instances. 
#
# 	- `models(options)` returns a Bacon.Property that sends the models 
# 		contained in the collection. Options is an object that can contain:
# 		- `get`: array or single model or id. This will make `models` return 
# 			an array containing only models with those ids.
# 		- `includeUndefined`: default to **false**, indicates if the returned
# 			array when the `get` option is specified, should include `undefined`
# 			for not found matches.
# 		The `get` option can be shortcut as a first parameter for `models`.
# 	- `validModels(options)` returns a Bacon.Property sending only models 
# 		whose `valid` Property is true. It accepts `models`.
# 	- `sortedModels(options)` returns a Bacon.Property sending models sorted 
# 		using a comparator. The comparator can be specified to the collection
# 		extension, as an instance construction option or as an option for this
# 		method:
# 		- `comparator`: a *string* indicating which model's attribute to use for
# 			natural sorting the results or a *function(a, b)* receiving two models
# 			attributes and returning the ordering between the two.
# 		The `comparator` option can be shortcut as a first parameter for 
# 		`sortedModels`; `models` options are also accepted.
# 	- `modelsAttributes(options)` returns a Bacon.Property that sends the 
# 		collection models attributes. It accepts options of models getters and:
# 		- `from`: by default to 'sortedModels', a string indicating from which 
# 			models getter to collect attributes; values are `'models'`, 
# 			`'validModels'` and `'sortedModels'`.
# 		- `pluck`: a model attribute name to retrieve instead of the complete 
# 			model attributes; if an array of names is specified, only the given
# 			attributes will be picked.
# 	- `add` modify the collection's content. It accepts the following 
# 		parameters:
# 		- *models, options*: adds or remove models depending on options. *Models*
# 			can be an array or single Model instance or collection of attributes.
# 		Options are:
# 		- `reset`: deafult to **false**, indicates if the model should be 
# 			emptied before adding the new content;
# 		- `at`: specify the index at which start to insert new attributes;
# 		Returns `models`.
# 	- `remove` modify the collection's content by removing models. It accepts
# 		an array of models or ids. Returns `models`.
Eggs.Collection = class Collection

	# The class of model elements contained in this collection. By default this
	# member is set to `Eggs.Model`.
	modelClass: Model

	# Called when constructing a new collection. By default this method does 
	# nothing.
	initialize: ->

	# `comparator` can be defined as a string indicating an attribute to be 
	# used for sorting or a function receiving a couple of models to compare.
	# The function should return 0 if the models are equal -1 if the first is
	# before the second and 1 otherwise. It will be used by `sortedModels` 
	# property.

	# `url` is the server URL to use to fetch collections. This URL will also be
	# used by collection's model when saving. Unlike models `url` this is a plain
	# string instead of a Property.

	# Parse is used to convert a server response into the array of attributes to 
	# be set as models for the collection instance.
	# It's a plain function returning an object that will be passed to
	# `add` from the default `fetch` implementation.
	parse: (response) -> 
		response

	# The constructor will generate the `models` method to access and modify
	# the Collection's elements.
	constructor: (cModels, cOptions = {}) ->
		@modelClass = cOptions.modelClass if cOptions.modelClass?
		@comparator = cOptions.comparator if cOptions.comparator?

		# The Bus used to push updated models and the relative Property.
		modelsBus = new Bacon.Bus
		modelsProperty = modelsBus.toProperty()
		modelsArray = []
		modelsByCId = {}

		# Activate modelsProperty
		modelsProperty.onValue ->

		# Utility function that will prepare a Model or an attributes object
		# to be added to this Collection
		prepareModel = (attrs, opts = {}) =>
			if attrs instanceof Model
				attrs.collection = @ unless attrs.collection?
				return attrs
			opts.collection = @
			new @modelClass(attrs, opts)

		# The main accessor to collection's models
		@models = (options) ->
			return modelsProperty if arguments.length == 0

			# options may be a shortcut for options.get, in that case there may be 
			# other options as a second parameter
			if options instanceof Model or not isHash(options)
				options = _.extend({ get:options }, arguments[1])
			return modelsProperty unless options.get?

			# Make sure that options.get is an array and make a copy of it to avoid
			# external changes
			idsAndModels = if _.isArray(options.get) then options.get.slice() else [options.get]
			includeUndefined = options.includeUndefined

			# Retrieve all the requested models
			Bacon.combineTemplate((if i instanceof Model then i.id() else i) for i in idsAndModels).flatMapLatest((idsOnly) -> 
				modelsProperty.flatMapLatest((models) ->
					Bacon.combineAsArray(m.id() for m in models).map((modelIds) ->
						results = []
						for id, idIndex in idsOnly
							indexInModels = -1
							indexInModels = modelIds.indexOf(id) if id?
							indexInModels = models.indexOf(idsAndModels[idIndex]) if indexInModels < 0
							if indexInModels >= 0
								results.push(models[indexInModels])
							else if includeUndefined
								results.push(undefined)
						results))).toProperty()

		# Method to add models to the collection content
		@add = (models, options) ->
			models = if _.isArray(models) then models.slice() else [models]
			options or= {}
			at = options.at ? modelsArray.length
			add = []
			if options.reset
				delete m.collection for m in modelsArray when m.collection is @
				modelsArray = []
				modelsByCId = {}
			for model in models
				model = prepareModel(model, options)
				unless modelsByCId[model.cid]?
					add.push(model)
					modelsByCId[model.cid] = model
			if add.length
				modelsArray[at..at-1] = add
			if add.length or options.reset
				modelsBus.push(modelsArray)
			modelsProperty

		# Method to remove models from the collection
		@remove = (idsAndModels) ->
			@models(idsAndModels).take(1).onValue((models) =>
				models = [models] unless _.isArray(models)
				for m in models
					delete m.collection if m.collection is @
					delete modelsByCId[m.cid]
				modelsArray = modelsArray.filter((v) -> models.indexOf(v) < 0)
				modelsBus.push(modelsArray))
			modelsProperty

		# Initialize models with constructor options
		@add(cModels ? [], cOptions)

		@initialize.apply(@, arguments)

	# Sends a model array only containing valid models
	validModels: (args...) ->
		@models(args...).flatMapLatest((ms) ->
			ms = [ms] unless _.isArray(ms)
			Bacon.combineTemplate((if m? then m.valid() else m) for m in ms).map((validArray) ->
				result = []
				for v, i in validArray
					if v
						result.push(ms[i])
					else if v isnt false
						result.push(v)
				result))
		.toProperty()

	# Sends an ordered models array if `comparator` is specified
	sortedModels: (args...) ->
		customComparator = @comparator
		if args.length >= 1 
			if _.isFunction(args[0]) or _.isString(args[0])
				customComparator = args[0]
				args = args.slice(1)
			if isHash(options = args[0]) or isHash(options = args[1])
				customComparator = options.comparator if options.comparator?
		return @validModels(args...) unless customComparator?
		unless _.isFunction(customComparator)
			comparator = (a, b) =>
				if a[0]?[customComparator] < b[0]?[customComparator] then -1
				else if a[0]?[customComparator] > b[0]?[customComparator] then 1
				else 0
		else
			comparator = (a, b) => customComparator(a[0], b[0])
		@validModels(args...).flatMapLatest((ms) ->
			Bacon.combineTemplate((if m? then m.attributes() else m) for m in ms).map((mattrs) ->
				([attrs, ms[i]] for attrs, i in mattrs)
				.sort(comparator)
				.map((am) -> am[1])))
		.toProperty()

	modelsAttributes: (args...) ->
		# Get options
		options = { from: 'sortedModels' }
		if args.length
			if not (args[0] instanceof Model) and isHash(args[0])
				options = _.extend(options, args[0])
			else if isHash(args[1])
				options = _.extend(options, args[1])

		# Get which attributes to pluck
		if _.isString(options.pluck)
			pluckSingle = options.pluck
		else if _.isArray(options.pluck)
			pluckMulti = options.pluck

		# Retrieve attributes and pluck if neccessary
		@[options.from](args...).flatMapLatest((ms) ->
			t = Bacon.combineTemplate((if m then m.attributes() else m) for m in ms)
			if pluckSingle?
				t = t.map((attrsArray) -> 
					attrsArray.filter((attrs) ->
						attrs?[pluckSingle]? or options.includeUndefined).map((attrs) -> 
							attrs[pluckSingle]))
			else if pluckMulti?
				t = t.map((attrsArray) -> 
					attrsArray.filter((attrs) ->
						attrs? or options.includeUndefined).map((attrs) -> 
							_.pick(attrs, pluckMulti)))
			t).toProperty()

	# Remove all collection's models and substitute them with those specified.
	reset: (models, options) ->
		@add(models, _.extend({}, options, { reset: true }))

	# Initiates an AJAX request to fetch the colleciton's content form the server
	# Returns a Bacon.EventStream that will send updated content once received.
	fetch: (options) ->
		options or= {}
		url = options.url ? @url
		throw new Error("Invalid URL for Collection #{@}") unless url?
		fetch = Bacon.fromPromise($.ajax
			type: 'GET'
			dataType: 'json'
			url: url)
		.flatMap((result) =>
			@add @parse(result), _.extend({ reset: yes }, options))
		.take(1).toProperty()
		fetch.onValue ->
		fetch

	# A utility method that will return a single options object from an arguments
	# array. The arguments array can contain a shortcut as it's first object.
	# For that one can specity which options it is shortcut and a method that 
	# will detect if the first parameter is a shortcut.
	# TODO make this working
	# @getOptionsWithShortcut = (shortcut, shortcutDetector, argsArray) ->
	# 	argsArray = shortcut if arguments.length < 3
	# 	options = {}
	# 	return options if argsArray.length is 0
	# 	if shortcutDetector?(argsArray[0])
	# 		options[shortcut] = argsArray[0]
	# 		argsArray = argsArray.slice(1)
	# 	options = _.extend(options, argsArray)


# UNTESTED WORK FROM THIS POINT
# -----------------------------

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

