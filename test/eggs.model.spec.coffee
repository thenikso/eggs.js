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

	describe "with default attributes", ->
		
		class TestModel extends Eggs.Model
				defaults:
					one: 'one'
					two: 'two'

		testModel = null

		beforeEach ->
			testModel = new TestModel two: 2

		it "should have Bacon.Property as proerties", ->
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

		it "should NOT push initial attributes if invalid", ->
			testModel = new TestModel one: 1
			expectPropertyEvents(
				-> 
					p = testModel.attributes.take(1)
					soon -> testModel.attributes.set({ one: 'one' })
					p
				[ { one: 'one' } ])


	