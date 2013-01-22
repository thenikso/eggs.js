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

	it "should have an `attributes` method returning a Bacon.Property", ->
		expect(_.isFunction(emptyTestModel.attributes)).toBeTruthy()
		expect(emptyTestModel.attributes() instanceof Bacon.Property).toBeTruthy()

	it "should have an `attributeNames` method returning a Bacon.Property", ->
		expect(_.isFunction(emptyTestModel.attributeNames)).toBeTruthy()
		expect(emptyTestModel.attributeNames() instanceof Bacon.Property).toBeTruthy()

	it "should have an `idAttribute` property equal to 'id'", ->
		expect(emptyTestModel.idAttribute).toEqual('id')

	it "should have an `id` method returning a Bacon.Property", ->
		expect(_.isFunction(emptyTestModel.id)).toBeTruthy()
		expect(emptyTestModel.id() instanceof Bacon.Property).toBeTruthy()		

	it "should have an `url` method returning a Bacon.Property", ->
		expect(_.isFunction(emptyTestModel.url)).toBeTruthy()
		expect(emptyTestModel.url() instanceof Bacon.Property).toBeTruthy()		

	it "should have a `fetch` method", ->
		expect(_.isFunction(emptyTestModel.fetch)).toBeTruthy()

	it "should have a `save` method", ->
		expect(_.isFunction(emptyTestModel.save)).toBeTruthy()

	describe "without attributes", () ->

		class TestModel extends Eggs.Model

		testModel = null

		beforeEach ->
			testModel = new TestModel

		it "should push an empty object form `attributes()`", ->
			expectPropertyEvents(
				-> testModel.attributes().take(1)
				[ {} ])

		it "should add new attributes when setting `attributes()`", ->
			expectPropertyEvents(
				->
					p = testModel.attributes().take(2)
					soon -> testModel.attributes({ one: 1 })
					p
				[ {}, { one: 1 }])

		it "should add a new property to `attributeNames` when setting `attributes()`", ->
			expectPropertyEvents(
				->
					p = testModel.attributeNames().take(2)
					soon -> testModel.attributes({ one: 1 })
					p
				[ [], ['one'] ])

		it "should push `undefined` for `id()`", ->
			expectPropertyEvents(
				-> testModel.id().take(1)
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
					soon -> testModel.attributes({ one: 1 })
					p
				[ { one: 'one', two: 2 }, { one: 1, two: 2 } ])

		it "should push single attributes when updated", ->
			expectPropertyEvents(
				-> 
					p = testModel.attributes('one').take(2)
					soon -> testModel.attributes('one', 1)
					p
				[ 'one', 1 ])

		it "should push attributes on single attributes update", ->
			expectPropertyEvents(
				-> 
					p = testModel.attributes().take(2)
					soon -> testModel.attributes('one', 1)
					p
				[ { one: 'one', two: 2 }, { one: 1, two: 2 } ])

		it "should push updated attributes from attributes set call", ->
			expectPropertyEvents(
				-> testModel.attributes({ one: 1 }).take(1)
				[ { one: 1, two: 2 } ])

		it "should NOT push attributes if nothing changed", ->
			expectPropertyEvents(
				->
					p = testModel.attributes().take(2)
					soon ->
						testModel.attributes({ two: 2 })
						testModel.attributes({ one: 1 })
					p
				[ { one: 'one', two: 2 }, { one: 1, two: 2 } ])

		it "should NOT push a single attribute if nothing changed", ->
			expectPropertyEvents(
				->
					p = testModel.attributes('one').take(2)
					soon ->
						testModel.attributes('one', 'one')
						testModel.attributes('one', 1)
					p
				[ 'one', 1 ])

		it "should NOT allow returned attributes object to alter the model's attributes", ->
			expectPropertyEvents(
				->
					p = testModel.attributeNames().take(4).map((v) -> v.sort())
					soon ->
						testModel.attributes().onValue((attr) ->
							attr.three = 3)
						testModel.attributes({ four: 4 })
						testModel.attributes(['two'], { unset: true })
						testModel.attributes(['one'], { unset: true })
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
					soon -> testModel.attributes({ three: 3 })
					p
				[ ['one', 'two'], ['one', 'three', 'two'] ])

		it "should remove attributes", ->
			expectPropertyEvents(
				->
					p = testModel.attributeNames().take(2).map((v) -> v.sort())
					soon -> testModel.attributes(['two', 'one'], { unset: true })
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
				expect(err).toEqual({ error: 'invalid', attributes: { one: 1 } })
			testModel.attributes({ one: 1 })

		it "should not validate if `shouldValidate` option is false", ->
			testModel = new TestModel({ one: 1 }, { shouldValidate: false })
			expectPropertyEvents(
				->
					p = testModel.attributes().take(2)
					soon -> testModel.attributes({ one: 2 })
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

		it "should NOT push initial attributes if invalid", ->
			expectPropertyEvents(
				-> 
					p = testModel.attributes().take(1)
					soon -> testModel.attributes({ one: 'one' })
					p
				[ { one: 'one' } ])

		it "should NOT push an initial single attributes if invalid", ->
			expectPropertyEvents(
				-> 
					p = testModel.attributes('one').take(1)
					soon -> testModel.attributes('one', 'one')
					p
				[ 'one' ])

		it "should NOT push initial attributeNames", ->
			expectPropertyEvents(
				->
					p = testModel.attributeNames().take(1).map((v) -> v.sort())
					soon -> testModel.attributes({ one: 'valid', two: 2 })
					p
				[ ['one', 'two'] ])

	describe "synching", ->

		origAjax = window.$.ajax
		ajaxMock = (options) ->
			d = new jQuery.Deferred
			setTimeout(
				->
					if options.type is 'GET'
						if options.url.indexOf('testurl/1') >= 0
							console.log 'GET OK'
							d.resolve { id: 1, one: 1, two: 2, three: 'three' }
						else
							console.log 'GET ERROR'
							d.reject "ajax read error"
					else
						if options.data?.id == 1
							console.log 'PUT OK'
							d.resolve { id: 1 }
						else
							console.log 'PUT ERROR'
							d.reject "ajax save error"
				300)
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
						testModel.attributes([ 'id' ], { unset: true })
					p
				[ 'testurl/1', 'testurl' ])

		it "should correctly fetch data", ->
			expectStreamEvents(
				-> testModel.fetch().take(1)
				[ { id: 1, one: 1, two: 2, three: 'three' } ])





		


	