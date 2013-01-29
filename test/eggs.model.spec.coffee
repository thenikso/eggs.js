describe "Eggs.Model", ->

	emptyTestModel = null

	beforeEach ->
		emptyTestModel = new Eggs.Model

	it "should exists", ->
		expect(Eggs.Model).toBeDefined()

	it "should be usable as class extension", ->
		class TestModel extends Eggs.Model
		testModel = new TestModel
		expect(testModel).not.toBeNull()

	it "should initialize", ->
		class TestModel extends Eggs.Model
			initialize: ->
				@one = 1
		testModel = new TestModel
		expect(testModel.one).toEqual(1)

	it "should initialize with attributes and options", ->
		class TestModel extends Eggs.Model
			initialize: (attributes, options) ->
				@one = options.one
		testModel = new TestModel({}, { one: 1 })
		expect(testModel.one).toEqual(1)

	it "should have an `idAttribute` property equal to 'id'", ->
		expect(emptyTestModel.idAttribute).toEqual('id')

	it "should have an `attributes` method returning a Bacon.Property", ->
		expect(_.isFunction(emptyTestModel.attributes)).toBeTruthy()
		expect(emptyTestModel.attributes() instanceof Bacon.Property).toBeTruthy()

	it "should have a `set` method returning a Bacon.Property", ->
		expect(_.isFunction(emptyTestModel.set)).toBeTruthy()
		expect(emptyTestModel.set({}) instanceof Bacon.Property).toBeTruthy()

	it "should have an unique `cid` for client id", ->
		otherModel = new Eggs.Model
		expect(emptyTestModel.cid).not.toBeNull()
		expect(otherModel.cid).not.toBeNull()
		expect(emptyTestModel.cid).not.toEqual(otherModel.cid)

	it "should have a `collection` member", ->
		expect(emptyTestModel.collection).toBeDefined()

	it "should have a `fetch` method", ->
		expect(_.isFunction(emptyTestModel.fetch)).toBeTruthy()

	it "should have a `save` method", ->
		expect(_.isFunction(emptyTestModel.save)).toBeTruthy()

	it "should have a `destroy` method", ->
		expect(_.isFunction(emptyTestModel.destroy)).toBeTruthy()

	it "should have an `attributeNames` method returning a Bacon.Property", ->
		expect(_.isFunction(emptyTestModel.attributeNames)).toBeTruthy()
		expect(emptyTestModel.attributeNames() instanceof Bacon.Property).toBeTruthy()

	it "should have a `valid` method returning a Bacon.Property", ->
		expect(_.isFunction(emptyTestModel.valid)).toBeTruthy()
		expect(emptyTestModel.valid() instanceof Bacon.Property).toBeTruthy()

	it "should have an `unset` method returning a Bacon.Property", ->
		expect(_.isFunction(emptyTestModel.unset)).toBeTruthy()
		expect(emptyTestModel.unset() instanceof Bacon.Property).toBeTruthy()		

	it "should have an `id` method returning a Bacon.Property", ->
		expect(_.isFunction(emptyTestModel.id)).toBeTruthy()
		expect(emptyTestModel.id() instanceof Bacon.Property).toBeTruthy()		

	it "should have an `url` method returning a Bacon.Property", ->
		expect(_.isFunction(emptyTestModel.url)).toBeTruthy()
		expect(emptyTestModel.url() instanceof Bacon.Property).toBeTruthy()

	describe "without attributes", () ->

		class TestModel extends Eggs.Model

		testModel = null

		beforeEach ->
			testModel = new TestModel

		it "should push an empty object form `attributes()`", ->
			expectPropertyEvents(
				-> testModel.attributes().take(1)
				[ {} ])

		it "should add new attributes", ->
			expectPropertyEvents(
				->
					p = testModel.attributes().take(2)
					soon -> testModel.set({ one: 1 })
					p
				[ {}, { one: 1 }])

		it "should add a new property to `attributeNames`", ->
			expectPropertyEvents(
				->
					p = testModel.attributeNames().take(2)
					soon -> testModel.set({ one: 1 })
					p
				[ [], ['one'] ])

		it "should push `undefined` for `id()`", ->
			expectPropertyEvents(
				-> testModel.id().take(1)
				[ undefined ])

		it "should push `undefined` for unexisting attribute", ->
			expectPropertyEvents(
				-> testModel.attributes('unexising').take(1)
				[ undefined ])

	describe "with default attributes", ->
		
		class TestModel extends Eggs.Model
				defaults:
					one: 'one'
					two: 'two'

		testModel = null

		beforeEach ->
			testModel = new TestModel two: 2

		it "should return Bacon.Property for each attribute in `attributes()`", ->
			expect(testModel.attributes('one') instanceof Bacon.Property).toBeTruthy()
			expect(testModel.attributes('two') instanceof Bacon.Property).toBeTruthy()

		it "should push attributes", ->
			expectPropertyEvents(
				-> testModel.attributes().take(1),
				[ { one: 'one', two: 2 } ])

		it "should push single attributes", ->
			expectPropertyEvents(
				-> testModel.attributes('one').take(1)
				[ 'one' ])
			expectPropertyEvents(
				-> testModel.attributes('two').take(1)
				[ 2 ])

		it "should push attributes on attributes update", ->
			expectPropertyEvents(
				->
					p = testModel.attributes().take(2)
					soon -> testModel.set({ one: 1 })
					p
				[ { one: 'one', two: 2 }, { one: 1, two: 2 } ])

		it "should push single attributes when updated", ->
			expectPropertyEvents(
				-> 
					p = testModel.attributes('one').take(2)
					soon -> testModel.set('one', 1)
					p
				[ 'one', 1 ])

		it "should push attributes on single attributes update", ->
			expectPropertyEvents(
				-> 
					p = testModel.attributes().take(2)
					soon -> testModel.set('one', 1)
					p
				[ { one: 'one', two: 2 }, { one: 1, two: 2 } ])

		it "should push updated attributes from attributes set call", ->
			expectPropertyEvents(
				-> testModel.set({ one: 1 }).take(1)
				[ { one: 1, two: 2 } ])

		it "should push updated attributes from single attributes set call", ->
			expectPropertyEvents(
				-> testModel.set('one', 1).take(1)
				[ { one: 1, two: 2 } ])

		it "should push updated attributes from attributes unset call", ->
			expectPropertyEvents(
				-> testModel.unset('one').take(1)
				[ { two: 2 } ])

		it "should NOT push attributes if nothing changed", ->
			expectPropertyEvents(
				->
					p = testModel.attributes().take(2)
					soon ->
						testModel.set({ two: 2 })
						testModel.set({ one: 1 })
					p
				[ { one: 'one', two: 2 }, { one: 1, two: 2 } ])

		it "should NOT push a single attribute if nothing changed", ->
			expectPropertyEvents(
				->
					p = testModel.attributes('one').take(2)
					soon ->
						testModel.set('one', 'one')
						testModel.set('one', 1)
					p
				[ 'one', 1 ])

		it "should NOT allow returned attributes object to alter the model's attributes", ->
			expectPropertyEvents(
				->
					p = testModel.attributeNames().take(4).map((v) -> v.sort())
					soon ->
						testModel.attributes().onValue((attr) ->
							attr.three = 3)
						testModel.set({ four: 4 })
						testModel.unset('two')
						testModel.unset(['one'])
					p
				[ ['one', 'two'], ['four', 'one', 'two'], ['four', 'one'], ['four'] ])
			
		it "should have correct `attributeNames` names", ->
			expectPropertyEvents(
				-> testModel.attributeNames().take(1).map((v) -> v.sort())
				[ ['one', 'two'] ])

		it "should add a new attribute", ->
			expectPropertyEvents(
				->
					p = testModel.attributeNames().take(2).map((v) -> v.sort())
					soon -> testModel.set({ three: 3 })
					p
				[ ['one', 'two'], ['one', 'three', 'two'] ])

		it "should remove attributes", ->
			expectPropertyEvents(
				->
					p = testModel.attributeNames().take(2).map((v) -> v.sort())
					soon -> testModel.set(['two', 'one'], { unset: true })
					p
				[ ['one', 'two'], [] ])
		
	describe "with validation", ->

		class TestModel extends Eggs.Model
				defaults:
					one: 'one'
				validate: (attr) ->
					"invalid" unless _.isString(attr.one)

		testModel = null

		beforeEach ->
			testModel = new TestModel

		it "should be valid", ->
			expectPropertyEvents(
				-> testModel.valid().take(1)
				[ true ])

		it "should push initial attributes", ->
			expectPropertyEvents(
				-> testModel.attributes().take(1),
				[ { one: 'one' } ])

		it "should push initial single attributes", ->
			expectPropertyEvents(
				-> testModel.attributes('one').take(1),
				[ 'one' ])

		it "should push an error on validation fail", ->
			testModel.attributes().onError (err) ->
				expect(err).toEqual('invalid')
			testModel.set({ one: 1 })

		it "should not validate if `shouldValidate` option is false", ->
			testModel = new TestModel({ one: 1 }, { shouldValidate: false })
			expectPropertyEvents(
				->
					p = testModel.attributes().take(2)
					soon -> testModel.set({ one: 2 })
					p
				[ {one: 1}, {one: 2} ])
			
	describe "when invalid", ->

		class TestModel extends Eggs.Model
				defaults:
					one: 'one'
				validate: (attr) ->
					"invalid" unless _.isString(attr.one)

		testModel = null

		beforeEach ->
			testModel = new TestModel one: 1

		it "should push and empty object for initial attributes if invalid", ->
			expectPropertyEvents(
				-> 
					p = testModel.attributes().take(2)
					soon -> testModel.set({ one: 'one' })
					p
				[ {}, { one: 'one' } ])

		it "should push undefined for an initial single attributes if invalid", ->
			expectPropertyEvents(
				-> 
					p = testModel.attributes('one').take(2)
					soon -> testModel.set('one', 'one')
					p
				[ undefined, 'one' ])

		it "should push and empty array for initial attributeNames when invalid", ->
			expectPropertyEvents(
				->
					p = testModel.attributeNames().take(2).map((v) -> v.sort())
					soon -> testModel.set({ one: 'valid', two: 2 })
					p
				[ [], ['one', 'two'] ])

		it "should return undefined for `id` when invalid", ->
			expectPropertyEvents(
				->
					p = testModel.id().take(2)
					soon -> testModel.set({ one: 'valid', id: 1 })
					p
				[ undefined, 1 ])

		it "should return `false` from `valid` property", ->
			expectPropertyEvents(
				-> testModel.valid().take(1)
				[ false ])

	describe "synching", ->

		origAjax = window.$.ajax
		ajaxMock = (options) ->
			d = new jQuery.Deferred
			setTimeout(
				->
					switch options.type 
						when 'GET'
							if options.url.indexOf('testurl/1') >= 0
								d.resolve { id: 1, one: 1, two: 2, three: 'three' }
							else
								d.reject "ajax read error"
						when 'PUT'
							if options.data?.id == 1
								d.resolve { id: 1 }
							else
								d.reject "ajax save error"
						when 'POST'
							if options.url.indexOf('/1') < 0 and not options.data?.id?
								d.resolve { id: 2, one: 'one', two: 'two' }
							else
								d.reject "ajax create error"
						when 'DELETE'
							if options.url.indexOf('testurl/1') >= 0
								d.resolve { status: 'ok' }
							else
								d.reject "ajax delete error"
						else 
							d.reject "ajax invalid request"
				100)
			d.promise()

		class TestModel extends Eggs.Model
			defaults:
				id: 1
				one: 'one'
				two: 'two'
			urlRoot: 'testurl/'

		testModel = null

		beforeEach ->
			window.$.ajax = ajaxMock
			testModel = new TestModel

		afterEach ->
			window.$.ajax = origAjax

		it "should push the correct id", ->
			expectPropertyEvents(
				-> testModel.id().take(1)
				[ 1 ])

		it "should push the correct url", ->
			expectPropertyEvents(
				-> 
					p = testModel.url().take(2)
					soon ->
						testModel.set([ 'id' ], { unset: true })
					p
				[ 'testurl/1', 'testurl' ])

		it "should correctly fetch data", ->
			expectStreamEvents(
				-> testModel.fetch().take(1)
				[ { id: 1, one: 1, two: 2, three: 'three' } ])

		it "should correctly update the model on save if id is set", ->
			expectStreamEvents(
				-> testModel.save().take(1)
				[ { id: 1, one: 'one', two: 'two' } ])

		it "should correctly save the model if id is not set", ->
			expectStreamEvents(
				-> testModel.unset('id').take(1).flatMap -> testModel.save().take(1)
				[ { id: 2, one: 'one', two: 'two' } ])

		it "should forward ajax error on fetch", ->
			expectStreamEvents(
				-> testModel.set('id', 2).take(1).flatMap -> testModel.fetch().take(1)
				[ error() ])

		it "should delete a model from the server if it exist", ->
			expectStreamEvents(
				-> testModel.destroy()
				[ { status: 'ok' } ])

		it "should push for delete even if the model is new", ->
			expectStreamEvents(
				-> testModel.unset('id').take(1).flatMap -> testModel.destroy()
				[ null ])
