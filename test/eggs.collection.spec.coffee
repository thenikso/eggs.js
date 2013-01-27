describe "Eggs.Collection", ->

	emptyCollection = null

	beforeEach ->
		emptyCollection = new Eggs.Collection

	it "should exists", ->
		expect(Eggs.Collection).toBeDefined()

	it "should have a `modelClass` member", ->
		expect(emptyCollection.modelClass).toBeDefined()

	it "should have an `initialize` member that is a function", ->
		expect(emptyCollection.initialize).toBeDefined()
		expect(_.isFunction(emptyCollection.initialize)).toBeTruthy()

	it "should have a `models` method", ->
		expect(emptyCollection.models).toBeDefined()

	it "should have a `validModels` method", ->
		expect(emptyCollection.validModels).toBeDefined()

	it "should have a `pluck` method returning a Bacon.Property", ->
		expect(emptyCollection.pluck).toBeDefined()
		expect(emptyCollection.pluck('a') instanceof Bacon.Property).toBeTruthy()

	describe "with models", ->

		class TestModel extends Eggs.Model
			validate: (attrs) ->
				'invalid' if attrs.number? and not _.isNumber(attrs.number)

		class TestCollection extends Eggs.Collection
			modelClass: TestModel

		testModel1 = null
		testModel2 = null
		testModel3 = null
		testCollection = null

		beforeEach ->
			testModel1 = new TestModel { one: 'one' }
			testModel2 = new TestModel { id: 2, one: 1, number: 2 }
			testModel3 = new TestModel { id: 2, number: 'nan' }
			testCollection = new TestCollection [ testModel1, testModel2, testModel3 ]

		it "should send initial models", ->
			expectPropertyEvents(
				-> testCollection.models().take(1)
				[ [ testModel1, testModel2, testModel3 ] ])

		it "should send valid models", ->
			expectPropertyEvents(
				-> testCollection.validModels().take(1)
				[ [ testModel1, testModel2 ] ])

		it "should pluck values", ->
			expectPropertyEvents(
				-> testCollection.pluck('one').take(1)
				[ ['one', 1] ])

