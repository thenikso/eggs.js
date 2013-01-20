describe "Eggs.Model", ->

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

	describe "without attributes", () ->

		class TestModel extends Eggs.Model

		testModel = null

		beforeEach ->
			testModel = new TestModel

		it "should define `attributes` Bacon.Property", ->
			expect(testModel.attributes instanceof Bacon.Property).toBeTruthy()

		it "should push an empty object form `attributes`", ->
			expectPropertyEvents(
				-> testModel.attributes.take(1)
				[ {} ])

		it "should have a Bacon.Property as `attributeNames`", ->
			expect(testModel.attributeNames instanceof Bacon.Property).toBeTruthy()

		it "should add new attributes when setting `attributes`", ->
			expectPropertyEvents(
				->
					p = testModel.attributes.take(2)
					soon -> testModel.attributes.set({ one: 1 })
					p
				[ {}, { one: 1 }])

		it "should add a new property to `attributeNames` when setting `attributes`", ->
			expectPropertyEvents(
				->
					p = testModel.attributeNames.take(2)
					soon -> testModel.attributes.set({ one: 1 })
					p
				[ [], ['one'] ])


	describe "with default attributes", ->
		
		class TestModel extends Eggs.Model
				defaults:
					one: 'one'
					two: 'two'

		testModel = null

		beforeEach ->
			testModel = new TestModel two: 2

		it "should have Bacon.Property as for each attribute in `attribute`", ->
			expect(testModel.attribute.one instanceof Bacon.Property).toBeTruthy()
			expect(testModel.attribute.two instanceof Bacon.Property).toBeTruthy()

		it "should push attributes", ->
			expectPropertyEvents(
				-> testModel.attributes.take(1),
				[ { one: 'one', two: 2 } ])

		it "should push single attributes", ->
			expectPropertyEvents(
				-> testModel.attribute.one.take(1)
				[ 'one' ])
			expectPropertyEvents(
				-> testModel.attribute.two.take(1)
				[ 2 ])

		it "should have `set` method for attributes", ->
			expect(testModel.attributes.set).toBeDefined()

		it "shuld have `set` method for single attributes", ->
			expect(testModel.attribute.one.set).toBeDefined()
			expect(testModel.attribute.two.set).toBeDefined()

		it "should push attributes on attributes update", ->
			expectPropertyEvents(
				->
					p = testModel.attributes.take(2)
					soon -> testModel.attributes.set({ one: 1 })
					p
				[ { one: 'one', two: 2 }, { one: 1, two: 2 } ])

		it "should push single attributes when updated", ->
			expectPropertyEvents(
				-> 
					p = testModel.attribute.one.take(2)
					soon -> testModel.attribute.one.set(1)
					p
				[ 'one', 1 ])

		it "should push attributes on single attributes update", ->
			expectPropertyEvents(
				-> 
					p = testModel.attributes.take(2)
					soon -> testModel.attribute.one.set(1)
					p
				[ { one: 'one', two: 2 }, { one: 1, two: 2 } ])

		it "should NOT push attributes if nothing changed", ->
			expectPropertyEvents(
				->
					p = testModel.attributes.take(2)
					soon ->
						testModel.attributes.set({ two: 2 })
						testModel.attributes.set({ one: 1 })
					p
				[ { one: 'one', two: 2 }, { one: 1, two: 2 } ])

		it "should NOT push a single attribute if nothing changed", ->
			expectPropertyEvents(
				->
					p = testModel.attribute.one.take(2)
					soon ->
						testModel.attribute.one.set('one')
						testModel.attribute.one.set(1)
					p
				[ 'one', 1 ])

		it "should have correct `attributeNames` names", ->
			expectPropertyEvents(
				-> testModel.attributeNames.take(1).map((v) -> v.sort())
				[ ['one', 'two'] ])

		it "should add a new attribute", ->
			expectPropertyEvents(
				->
					p = testModel.attributeNames.take(2).map((v) -> v.sort())
					soon -> testModel.attributes.set({ three: 3 })
					p
				[ ['one', 'two'], ['one', 'three', 'two'] ])
		
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
				-> testModel.attributes.take(1),
				[ { one: 'one' } ])

		it "should push initial single attributes", ->
			expectPropertyEvents(
				-> testModel.attribute.one.take(1),
				[ 'one' ])

		it "should push an error on validation fail", ->
			testModel.attributes.onError (err) ->
				expect(err).toEqual({ error: 'invalid', attributes: { one: 1 } })
			testModel.attributes.set({ one: 1 })

		it "should not validate if `shouldValidate` option is false", ->
			testModel = new TestModel({ one: 1 }, { shouldValidate: false })
			expectPropertyEvents(
				->
					p = testModel.attributes.take(2)
					soon -> testModel.attributes.set({ one: 2 })
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
					p = testModel.attributes.take(1)
					soon -> testModel.attributes.set({ one: 'one' })
					p
				[ { one: 'one' } ])

		it "should NOT push an initial single attributes if invalid", ->
			expectPropertyEvents(
				-> 
					p = testModel.attribute.one.take(1)
					soon -> testModel.attribute.one.set('one')
					p
				[ 'one' ])

		it "should NOT push initial attributeNames", ->
			expectPropertyEvents(
				->
					p = testModel.attributeNames.take(1).map((v) -> v.sort())
					soon -> testModel.attributes.set({ one: 'valid', two: 2 })
					p
				[ ['one', 'two'] ])


	