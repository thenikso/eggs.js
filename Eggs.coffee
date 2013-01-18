
Eggs = @Eggs = {}

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

# Model
class Model
	constructor: (attributes, options) ->
		options = _.defaults({
			validate: true
		}, options)

		# Get model instance attributes
		attrs = attributes or {}
		attrs = _.defaults({}, attrs, defaults) if defaults = _.result(@, 'defaults')

		# Create property busses. This are used to set the properties
		@busses = {}
		@uncheckedProperties = {}
		for propertyName, propertyDefault of attrs
			@busses[propertyName] = bus = new Bacon.Bus 
			@uncheckedProperties[propertyName] = bus.toProperty(propertyDefault)

		# The bus and relative property that will send validated attributes
		# or validation errors.
		@attributesBus = new Bacon.Bus
		@attributes = @attributesBus.toProperty(attrs)

		# The validation process starts by combining all the unchecked properties
		# and pass them throught the validate method. Reflects on attributes.
		@uncheckedAttributes = Bacon.combineTemplate(@uncheckedProperties)
		@uncheckedAttributes.onValue (attrObject) =>
			if options.validate and error = @validate?(attrObject)
				@attributesBus.error(error)
			else
				@attributesBus.push(attrObject)
			
		# Validated properties extracted from validated attributes
		@properties = {}
		for propertyName of attrs
			@properties[propertyName] = @attributes.map(".#{propertyName}")

	property: (propertyName, value) ->
		if _.isUndefined(value)
			@properties[propertyName]
		else
			@busses[propertyName]?.push(value)

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


