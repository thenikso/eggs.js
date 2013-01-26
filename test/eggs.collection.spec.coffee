describe "Eggs.Collection", ->

	emptyCollection = null

	beforeEach ->
		emptyCollection = new Eggs.Collection

	it "should exists", ->
		expect(Eggs.Collection).toBeDefined()

	it "should have an `initialize` member that is a function", ->
		expect(emptyCollection.initialize).toBeDefined()
		expect(_.isFunction(emptyCollection.initialize)).toBeTruthy()

	it "should have a `modelClass` member", ->
		expect(emptyCollection.modelClass).toBeDefined()
