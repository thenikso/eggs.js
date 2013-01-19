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

		it "should have a Bacon.Property as `propertyNames`", ->
			expect(testModel.propertyNames instanceof Bacon.Property).toBeTruthy()

		it "should add new attributes when setting `attributes`", ->
			expectPropertyEvents(
				->
					p = testModel.attributes.take(2)
					soon -> testModel.attributes.set({ one: 1 })
					p
				[ {}, { one: 1 }])

		it "should add a new property to `propertyNames` when setting `attributes`", ->
			expectPropertyEvents(
				->
					p = testModel.propertyNames.take(2)
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

		it "should have Bacon.Property as for each property in `proerties`", ->
			expect(testModel.properties.one instanceof Bacon.Property).toBeTruthy()
			expect(testModel.properties.two instanceof Bacon.Property).toBeTruthy()

		it "should push attributes", ->
			expectPropertyEvents(
				-> testModel.attributes.take(1),
				[ { one: 'one', two: 2 } ])

		it "should push properties", ->
			expectPropertyEvents(
				-> testModel.properties.one.take(1)
				[ 'one' ])
			expectPropertyEvents(
				-> testModel.properties.two.take(1)
				[ 2 ])

		it "should have `set` method for attributes", ->
			expect(testModel.attributes.set).toBeDefined()

		it "shuld have `set` method for properties", ->
			expect(testModel.properties.one.set).toBeDefined()
			expect(testModel.properties.two.set).toBeDefined()

		it "should push attributes on attributes update", ->
			expectPropertyEvents(
				->
					p = testModel.attributes.take(2)
					soon -> testModel.attributes.set({ one: 1 })
					p
				[ { one: 'one', two: 2 }, { one: 1, two: 2 } ])

		it "should push property on property update", ->
			expectPropertyEvents(
				-> 
					p = testModel.properties.one.take(2)
					soon -> testModel.properties.one.set(1)
					p
				[ 'one', 1 ])

		it "should push attributes on property update", ->
			expectPropertyEvents(
				-> 
					p = testModel.attributes.take(2)
					soon -> testModel.properties.one.set(1)
					p
				[ { one: 'one', two: 2 }, { one: 1, two: 2 } ])

		it "should NOT push attributes if no changes", ->
			expectPropertyEvents(
				->
					p = testModel.attributes.take(2)
					soon ->
						testModel.attributes.set({ two: 2 })
						testModel.attributes.set({ one: 1 })
					p
				[ { one: 'one', two: 2 }, { one: 1, two: 2 } ])

		it "should NOT push a property if no changes", ->
			expectPropertyEvents(
				->
					p = testModel.properties.one.take(2)
					soon ->
						testModel.properties.one.set('one')
						testModel.properties.one.set(1)
					p
				[ 'one', 1 ])

		it "should have correct `propertyNames` names", ->
			expectPropertyEvents(
				-> testModel.propertyNames.take(1).map((v) -> v.sort())
				[ ['one', 'two'] ])

		it "should add a new property", ->
			expectPropertyEvents(
				->
					p = testModel.propertyNames.take(2).map((v) -> v.sort())
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

		it "should push initial property", ->
			expectPropertyEvents(
				-> testModel.properties.one.take(1),
				[ 'one' ])

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

		it "should NOT push an initial property if invalid", ->
			expectPropertyEvents(
				-> 
					p = testModel.properties.one.take(1)
					soon -> testModel.properties.one.set('one')
					p
				[ 'one' ])

		it "should NOT push initial propertyNames", ->
			expectPropertyEvents(
				->
					p = testModel.propertyNames.take(1).map((v) -> v.sort())
					soon -> testModel.attributes.set({ one: 'valid', two: 2 })
					p
				[ ['one', 'two'] ])


	