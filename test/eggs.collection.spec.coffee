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

	it "should have a `pluck` method", ->
		expect(emptyCollection.pluck).toBeDefined()

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
			testModel3 = new TestModel { id: 3, number: 'nan' }
			testCollection = new TestCollection [ testModel1, testModel2, testModel3 ]

		it "should send initial models", ->
			expectPropertyEvents(
				-> testCollection.models().take(1)
				[ [testModel1, testModel2, testModel3] ])

		it "should send valid models", ->
			expectPropertyEvents(
				-> testCollection.validModels().take(1)
				[ [testModel1, testModel2] ])

		it "should update valid models when a model becomes valid", ->
			expectPropertyEvents(
				->
					p = testCollection.validModels().take(2)
					soon ->
						testModel3.attributes('number', 5)
					p
				[ [testModel1, testModel2], [testModel1, testModel2, testModel3] ])

		it "should add a model to the collection", ->
			testModel4 = new TestModel
			expectPropertyEvents(
				-> testCollection.models(testModel4).take(1)
				[ [testModel1, testModel2, testModel3, testModel4] ])

		it "should pluck values", ->
			expectPropertyEvents(
				-> testCollection.pluck('one').take(1)
				[ ['one', 1] ])

		it "should add a model to the collection from attributes", ->
			expectPropertyEvents(
				-> 
					p = testCollection.pluck('one').take(2)
					soon ->
						testCollection.models({ one: 'ONE' })
					p
				[ ['one', 1], ['one', 1, 'ONE'] ])

		it "should NOT add a model if already in the collection", ->
			expectPropertyEvents(
				-> testCollection.models(testModel1).take(1)
				[ [testModel1, testModel2, testModel3] ])

		it "should insert a model at a specified location", ->
			testModel4 = new TestModel
			expectPropertyEvents(
				-> testCollection.models(testModel4, { at: 0 }).take(1)
				[ [testModel4, testModel1, testModel2, testModel3] ])

		it "`validModels` should be usable like `models`", ->
			testModel4 = new TestModel
			expectPropertyEvents(
				-> testCollection.validModels(testModel4, { at: 1 }).take(1)
				[ [testModel1, testModel4, testModel2] ])


