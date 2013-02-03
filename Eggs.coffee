# Eggs 0.0.1

# Utilities
# ---------

isHash = (obj) -> (obj instanceof Object) and not (obj instanceof Array) and (typeof obj isnt 'array')

# Environment
# -----------

Eggs = @Eggs = {}

# Bacon extensions
# ----------------

# Get a field from an object
Bacon.Observable.prototype.get = (field) ->
	@map (obj) -> obj[field]

# Pluck a filed from an array of objects
Bacon.Observable.prototype.pluck = (field) ->
	@filter(_.isArray).map((obj) -> _.pluck(obj, field))

# Pick the given fields from an object
Bacon.Observable.prototype.pick = (fields...) ->
	@filter(_.isObject).map (obj) -> _.pick(obj, fields...)

# Sends array of keys derived from an object
Bacon.Observable.prototype.keys = ->
	@filter(_.isObject).map(_.keys)

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
# 		Validation errors are sent through. 
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
		@attributes = ->
			return attributesProperty

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
			.toProperty()

		# Activate the fetch reaction
		fetch.onValue -> Bacon.noMore
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
			.toProperty()

		# Activate the save operation
		save.onValue -> Bacon.noMore
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

# Collection specific utility to extract attributes from a Models array.
# Returns a Bacon.Property.
Bacon.Observable.prototype.attributes = ->
	@flatMapLatest((models) ->
		Bacon.combineTemplate((if m then m.attributes?() else m) for m in models))
	.toProperty()

# An `Eggs.Collection` groups together multiple model instances. 
#
# 	- `models(options)` returns a Bacon.Property that sends the models 
# 		contained in the collection. Options is an object that can contain:
# 		- `get`: array or single model or id. This will make `models` return 
# 			an array containing only models with those ids.
# 		- `valid`: default to **false** will make the property only push valid 
# 			models.
# 		- `sorted`: default to **false** will make the property push sorted 
# 			models. If true, the collection's comparator will be used. The 
# 			comparator can be specified to the collection extension, as an 
# 			instance construction option or directly specified as `sorted`. The 
# 			comparator can be a *string* indicating which model's attribute 
# 			to use for natural sorting the results or a *function(a, b)* receiving 
# 			two models attributes and returning the ordering between the two.
# 	- `modelsAttributes(options)` returns a Bacon.Property that sends the 
# 		collection models attributes. It accepts options of models getters and:
# 		- `from`: by default to 'sortedModels', a string indicating from which 
# 			models getter to collect attributes; values are `'models'`, 
# 			`'validModels'` and `'sortedModels'`.
# 		- `pluck`: a model attribute name to retrieve instead of the complete 
# 			model attributes; if an array of names is specified, only the given
# 			attributes will be picked.
# 	- `add` modify the collection's content. If a model already exists it will 
# 		be skipped unless `merge` or `update` is specified; in that case models 
# 		will be merged or updated with new attributes *after* the collection 
# 		update. It accepts the following parameters:
# 		- *models, options*: adds or remove models depending on options. *Models*
# 			can be an array or single Model instance or collection of attributes.
# 		Options are:
# 		- `reset`: deafult to **false**, indicates if the model should be 
# 			emptied before adding the new content;
# 		- `merge`: default to **false**, indicates if added models with the same 
# 			idAttribute to existing models should be merged;
# 		- `update`: default to **false**, is similar to `merge` but instead of 
# 			merging models having the same idAttribute it will substitute them;
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

	# `idAttribute` can be defined as a string indicating the model attribute 
	# name that the collection should use as id. If not specified, the 
	# modelClass.idAttribute will be used.

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
		@models = (args...) ->
			# options may be a shortcut for options.get, in that case there may be 
			# other options as a second parameter
			options = {}
			if args.length
				if args[0] instanceof Model or _.isNumber(args[0]) or _.isString(args[0]) or _.isArray(args[0])
					options = { get: args[0] }
					args = args.slice(1)
				options = _.extend(options, args...)

			models = modelsProperty

			if options.get?
				# Make sure that options.get is an array and make a copy of it to avoid
				# external changes
				idsAndModels = if _.isArray(options.get) then options.get.slice() else [options.get]

				# Retrieve all the requested models
				models = Bacon.combineTemplate((if i instanceof Model then i.id() else i) for i in idsAndModels).flatMapLatest((idsOnly) -> 
					modelsProperty.flatMapLatest((ms) ->
						Bacon.combineAsArray(m.id() for m in ms).map((modelIds) ->
							results = []
							for id, idIndex in idsOnly
								indexInModels = -1
								indexInModels = modelIds.indexOf(id) if id?
								indexInModels = ms.indexOf(idsAndModels[idIndex]) if indexInModels < 0
								if indexInModels >= 0
									results.push(ms[indexInModels])
							results))).toProperty()

			# Get valid models if needed
			if options.valid
				models = models.flatMapLatest((ms) ->
					Bacon.combineAsArray(m.valid() for m in ms)
					.map((validArray) ->
						result = []
						for v, i in validArray
							result.push(ms[i]) if v
						result))
				.toProperty()

			# Get sorted models if needed
			if options.sorted or options.comparator?
				comparator = options.sorted unless _.isBoolean(options.sorted)
				comparator = options.comparator if options.comparator?
				comparator ?= @comparator
				throw new Error("Invalid comparator for sorted models: #{comparator}") unless comparator?
				unless _.isFunction(comparator)
					comparatorFunction = (a, b) =>
						if a[0]?[comparator] < b[0]?[comparator] then -1
						else if a[0]?[comparator] > b[0]?[comparator] then 1
						else 0
				else
					comparatorFunction = (a, b) => comparator(a[0], b[0])
				models = models.flatMapLatest((ms) ->
					Bacon.combineAsArray(m.attributes() for m in ms)
					.map((mattrs) ->
						([attrs, ms[i]] for attrs, i in mattrs)
						.sort(comparatorFunction)
						.map((am) -> am[1])))
				.toProperty()

			# Return the builded models property
			models

		# The models Property is decorated with a `collection` attribute
		@models.collection = @

		# Method to add models to the collection content
		@add = (models, options) ->
			models = if _.isArray(models) then models.slice() else [models]
			options or= {}
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
			if modelsArray.length
				if add.length
					# Prepare to add new models in a non empty collection
					at = options.at ? modelsArray.length
					options.update = no if options.merge
					@idAttribute = modelsArray[0].idAttribute unless @idAttribute?
					# Update will contain objects with `model` and `set` that should 
					# be set after updating the collection
					updateModels = []
					Bacon.combineAsArray(m.attributes() for m in modelsArray)
					.take(1).flatMapLatest((modelsAttributes) =>
						# Get all the ids of the models currently in the collection; this 
						# will have the same index as models in modelsArray
						modelsIds = _.pluck(modelsAttributes, @idAttribute)
						# Get add array models attributes
						Bacon.combineAsArray(m.attributes() for m in add)
						.take(1).flatMapLatest((addAttributes) =>
							# cleanAdd will have all the models actually to add after updates 
							# of existing ones
							cleanAdd = []
							for addAttrs, addIndex in addAttributes
								# Get the index of the model in modelsArray of an already 
								# present model
								if (addId = addAttrs[@idAttribute]) and (modelIndex = _.indexOf(modelsIds, addId)) >= 0
									# With update or merge option, will set the existing model
									# after the collection update
									updateModels.push({ model: modelsArray[modelIndex], set: addAttrs }) if options.update?
									continue
								# If no conflicts, add to cleanAdd
								cleanAdd.push(add[addIndex])
							# We can finally add to the modelsArray and push the update
							if cleanAdd.length
								modelsArray[at..at-1] = cleanAdd
								modelsBus.push(modelsArray)
							# Will return the models property already updated with the change
							modelsProperty))
					# Activate the operation
					.onValue -> Bacon.noMore
					# Update single models
					for u in updateModels
						u.model.set(u.set, { reset: options.update })
					# Just return modelsProperty as the previous reaction will be 
					# already executed at this point
					return modelsProperty
			else
				# Adding models to a currently empty collection
				modelsArray = add
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
		args.push({ valid: yes })
		@models(args...)

	# Sends an ordered models array if `comparator` is specified
	sortedModels: (args...) ->
		if args.length
			if _.isString(args[0]) or _.isFunction(args[0])
				args = [{ valid: yes, sorted: args[0] }].concat(args.slice(1))
			else
				args.push({ valid: yes, sorted: yes })
		else
			args = [{ valid: yes, sorted: yes }]
		@models(args...)

	# Remove all collection's models and substitute them with those specified.
	reset: (models, options) ->
		@add(models, _.extend({}, options, { reset: true }))

	# Initiates an AJAX request to fetch the colleciton's content form the server
	# Returns a Bacon.Property that will send updated content once received.
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
		.toProperty()
		fetch.onValue -> Bacon.noMore
		fetch

# Bacon.Property.prototype.attributes
# TODO make validModels, sortedModels as methods to models() property.
# TODO make attributes as method to models() property (and sorted, valid)
# TODO add `create` or `sync` option to add and `waitSync`

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

