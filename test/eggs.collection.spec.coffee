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

	it "should have a `models` method returning a Bacon.Property", ->
		expect(emptyCollection.models).toBeDefined()
		expect(emptyCollection.models() instanceof Bacon.Property).toBeTruthy()

	it "should have a `add` method returning a Bacon.Property", ->
		expect(emptyCollection.add).toBeDefined()
		expect(emptyCollection.add([]) instanceof Bacon.Property).toBeTruthy()

	it "should have a `remove` method returning a Bacon.Property", ->
		expect(emptyCollection.remove).toBeDefined()
		expect(emptyCollection.remove([]) instanceof Bacon.Property).toBeTruthy()

	it "should have a `validModels` method returning a Bacon.Property", ->
		expect(emptyCollection.validModels).toBeDefined()
		expect(emptyCollection.validModels() instanceof Bacon.Property).toBeTruthy()

	it "should have a `sortedModels` method returning a Bacon.Property", ->
		expect(emptyCollection.sortedModels).toBeDefined()
		expect(emptyCollection.sortedModels() instanceof Bacon.Property).toBeTruthy()

	it "should have a `modelsAttributes` method", ->
		expect(emptyCollection.modelsAttributes).toBeDefined()

	it "should have a `reset` method", ->
		expect(emptyCollection.reset).toBeDefined()

	it "should have a `fetch` method", ->
		expect(emptyCollection.fetch).toBeDefined()

	it "should properly parse `model` function arguments", ->
		testModel = new Eggs.Model
		expect(Eggs.Collection.parseModelsArguments([])).toEqual({ get: [] })
		expect(Eggs.Collection.parseModelsArguments({ a: 1 })).toEqual({ a: 1 })
		expect(Eggs.Collection.parseModelsArguments(3, { a: 1 }, { b: 2 })).toEqual({ get: 3, a: 1, b: 2 })
		expect(Eggs.Collection.parseModelsArguments(testModel)).toEqual({ get: testModel })

	it "should properly parse `sortedModels` function arguments", ->
		testModel = new Eggs.Model
		testComparator = -> true
		expect(Eggs.Collection.parseSortedModelsArguments({ a: 1 })).toEqual({ a: 1 })
		expect(Eggs.Collection.parseSortedModelsArguments('a')).toEqual({ comparator: 'a' })
		expect(Eggs.Collection.parseSortedModelsArguments(testComparator)).toEqual({ comparator: testComparator })
		expect(Eggs.Collection.parseSortedModelsArguments(testModel)).toEqual({ get: testModel })
		expect(Eggs.Collection.parseSortedModelsArguments(testComparator, { comparator: 'a' }, { b: 2 })).toEqual({ comparator: 'a', b: 2 })

	describe "with models and validation", ->

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
			expectPropertyEvents(
				-> testCollection.models({}).take(1)
				[ [testModel1, testModel2, testModel3] ])

		it "should send single models", ->
			expectPropertyEvents(
				-> testCollection.models({ get: testModel2 }).take(1)
				[ [testModel2] ])
			expectPropertyEvents(
				-> testCollection.models(testModel2).take(1)
				[ [testModel2] ])
			expectPropertyEvents(
				-> testCollection.models(2).take(1)
				[ [testModel2] ])
			expectPropertyEvents(
				-> testCollection.models([testModel3, testModel2]).take(1)
				[ [testModel3, testModel2] ])
			expectPropertyEvents(
				-> testCollection.models([3, testModel2]).take(1)
				[ [testModel2] ])
			testModel4 = new TestModel
			expectPropertyEvents(
				-> testCollection.models(testModel4, { includeUndefined: yes }).take(1)
				[ [undefined] ])
			expectPropertyEvents(
				-> testCollection.models({ get: [2, testModel4], includeUndefined: yes }).take(1)
				[ [testModel2, undefined] ])
			testModel5 = new TestModel id: 2
			expectPropertyEvents(
				-> testCollection.models([2, testModel5]).take(1)
				[ [testModel2, testModel2] ])

		it "should send valid models", ->
			expectPropertyEvents(
				-> testCollection.validModels().take(1)
				[ [testModel1, testModel2] ])

		it "should send valid single models", ->
			expectPropertyEvents(
				-> testCollection.validModels([-1, testModel3, testModel2], { includeUndefined: yes }).take(1)
				[ [undefined, testModel2] ])

		it "should update valid models when a model becomes valid", ->
			expectPropertyEvents(
				->
					p = testCollection.validModels().take(2)
					soon ->
						testModel3.set('number', 5)
					p
				[ [testModel1, testModel2], [testModel1, testModel2, testModel3] ])

		it "should add a model to the collection", ->
			testModel4 = new TestModel
			expectPropertyEvents(
				-> testCollection.add(testModel4).take(1)
				[ [testModel1, testModel2, testModel3, testModel4] ])

		it "should remove a model from the collection", ->
			expectPropertyEvents(
				-> 
					p = testCollection.remove(testModel3).take(2)
					soon -> testCollection.remove([2, testModel1])
					p
				[ [testModel1, testModel2], [] ])

		it "should add a model to the collection from attributes", ->
			expectPropertyEvents(
				-> 
					p = testCollection.modelsAttributes({ from: 'models', pluck: 'one'}).take(2)
					soon ->
						testCollection.add({ one: 'ONE' })
					p
				[ ['one', 1], ['one', 1, 'ONE'] ])

		it "should merge a model when adding if the id is the same", ->
			expectPropertyEvents(
				->
					p = testCollection.modelsAttributes().take(3)
					soon ->
						testCollection.add([{ id: 2, one: 'ONE' }, { id: 4, number: 4 }], { merge: yes })
					p
				[ [{ one: 'one' }, { id: 2, one: 1, number: 2 }], 
					[{ one: 'one' }, { id: 2, one: 1, number: 2 }, { id: 4, number: 4 }],
					[{ one: 'one' }, { id: 2, one: 'ONE', number: 2 }, { id: 4, number: 4 }] ])

		it "should NOT add a model if already in the collection", ->
			expectPropertyEvents(
				-> testCollection.add(testModel1).take(1)
				[ [testModel1, testModel2, testModel3] ])

		it "should insert a model at a specified location", ->
			testModel4 = new TestModel
			expectPropertyEvents(
				-> testCollection.add(testModel4, { at: 0 }).take(1)
				[ [testModel4, testModel1, testModel2, testModel3] ])

		it "`validModels` should get single models like `models`", ->
			testModel4 = new TestModel id: 2
			expectPropertyEvents(
				-> testCollection.validModels(testModel4).take(1)
				[ [testModel2] ])
			expectPropertyEvents(
				-> testCollection.validModels(2).take(1)
				[ [testModel2] ])
			expectPropertyEvents(
				-> testCollection.validModels([testModel4, 3]).take(1)
				[ [testModel2] ])

		it "should reset the collection and add new models", ->
			testModel4 = new TestModel
			expectPropertyEvents(
				-> 
					p = testCollection.add([testModel1, testModel4], { reset: true }).take(2)
					soon ->
						testCollection.reset([]).onValue ->
							expect(testModel1.collection).not.toBeDefined()
					p
				[ [testModel1, testModel4], [] ])

	describe "with sorting", ->

		class TestModel extends Eggs.Model
			validate: (attrs) ->
				'invalid' if attrs.number? and not _.isNumber(attrs.number)

		class TestCollection extends Eggs.Collection
			modelClass: TestModel
			comparator: (a, b) ->
				a.order - b.order

		testModel1 = null
		testModel2 = null
		testModel3 = null
		testCollection = null

		beforeEach ->
			testModel1 = new TestModel { one: 'one', order: 3 }
			testModel2 = new TestModel { id: 2, one: 1, number: 2, order: 2 }
			testModel3 = new TestModel { id: 3, number: 'nan', order: 1 }
			testCollection = new TestCollection [ testModel1, testModel2, testModel3 ]

		it "should send ordered models with comparator function", ->
			expectPropertyEvents(
				-> testCollection.sortedModels().take(1)
				[ [testModel2, testModel1] ])

		it "should send ordered models with string as comparator", ->
			testCollection = new TestCollection(
				[ testModel1, testModel2, testModel3 ],
				{ comparator: 'order' })
			expectPropertyEvents(
				-> testCollection.sortedModels().take(1)
				[ [testModel2, testModel1] ])

		it "should accept a comparator as option", ->
			expectPropertyEvents(
				-> testCollection.sortedModels({ comparator: (a,b) -> b.order - a.order }).take(1)
				[ [testModel1, testModel2] ])

		it "should be able to specify a comparator function for sorting", ->
			expectPropertyEvents(
				-> testCollection.sortedModels((a,b) -> b.order - a.order).take(1)
				[ [testModel1, testModel2] ])

		it "should be able to specify an attribute name as comparator for sorting", ->
			expectPropertyEvents(
				-> testCollection.sortedModels('one').take(1)
				[ [testModel1, testModel2] ])

		it "should sort single models", ->
			expectPropertyEvents(
				-> testCollection.sortedModels(2).take(1)
				[ [testModel2] ])
			expectPropertyEvents(
				-> testCollection.sortedModels([2, 3]).take(1)
				[ [testModel2] ])
			expectPropertyEvents(
				-> testCollection.sortedModels(-1, { includeUndefined: yes }).take(1)
				[ [undefined] ])
			expectPropertyEvents(
				-> testCollection.sortedModels('one', { get: [-1, testModel1, 2], includeUndefined: yes }).take(1)
				[ [undefined, testModel1, testModel2] ])

		it "should send models attributes", ->
			expectPropertyEvents(
				-> testCollection.modelsAttributes({ get: 2 }).take(1)
				[ [{ id: 2, one: 1, number: 2, order: 2 }] ])
			expectPropertyEvents(
				-> testCollection.modelsAttributes().take(1)
				[ [{ id: 2, one: 1, number: 2, order: 2 }, { one: 'one', order: 3 }] ])
			expectPropertyEvents(
				-> testCollection.modelsAttributes(-1, { includeUndefined: yes }).take(1)
				[ [undefined] ])
			expectPropertyEvents(
				-> testCollection.modelsAttributes({ from: 'models', pluck: 'one', includeUndefined: yes }).take(1)
				[ ['one', 1, undefined] ])
			expectPropertyEvents(
				-> testCollection.modelsAttributes({ from: 'validModels' }).take(1)
				[ [{ one: 'one', order: 3 }, { id: 2, one: 1, number: 2, order: 2 }] ])

	describe "with AJAX update", ->

		origAjax = window.$.ajax
		ajaxMock = (options) ->
			d = new jQuery.Deferred
			setTimeout(
				->
					switch options.type 
						when 'GET'
							if options.url.indexOf('testcollection') >= 0
								d.resolve [{ id: 1, field: '1' }, { id: 2, field: '2' }, { id: 3, field: '3' }]
							else
								d.reject "ajax read error"
						# when 'PUT'
						# 	if options.data?.id == 1
						# 		d.resolve { id: 1 }
						# 	else
						# 		d.reject "ajax save error"
						# when 'POST'
						# 	if options.url.indexOf('/1') < 0 and not options.data?.id?
						# 		d.resolve { id: 2, one: 'one', two: 'two' }
						# 	else
						# 		d.reject "ajax create error"
						# when 'DELETE'
						# 	if options.url.indexOf('testurl/1') >= 0
						# 		d.resolve { status: 'ok' }
						# 	else
						# 		d.reject "ajax delete error"
						else 
							d.reject "ajax invalid request"
				100)
			d.promise()

		class TestModel extends Eggs.Model
			validate: (attrs) ->
				'invalid' if attrs.field? and _.isNumber(attrs.field)

		class TestCollection extends Eggs.Collection
			modelClass: TestModel
			url: 'testcollection/' 
			comparator: 'id'

		testModel1 = null
		testModel2 = null
		testModel3 = null
		testCollection = null

		beforeEach ->
			window.$.ajax = ajaxMock
			testModel1 = new TestModel { field: 'one' }
			testModel2 = new TestModel { id: 2, field: 'two' }
			testModel3 = new TestModel { id: 3, field: 3 }
			testCollection = new TestCollection [ testModel1, testModel2, testModel3 ]

		afterEach ->
			window.$.ajax = origAjax

		it "should fetch data from the database", ->
			expectPropertyEvents(
				-> 
					p = testCollection.modelsAttributes({ pluck: 'id' }).take(2)
					soon -> testCollection.fetch()
					p
				[ [2], [1, 2, 3] ])

		it "should fetch without resetting the collection content", ->
			expectPropertyEvents(
				-> 
					p = testCollection.modelsAttributes().take(3)
					soon -> testCollection.fetch({ reset: no, merge: yes })
					p
				[ [{ field: 'one' }, { id: 2, field: 'two' }], 
					[{ field: 'one' }, { id: 1, field: '1' }, { id: 2, field: 'two' }, { id: 3, field: '3' }],
					[{ field: 'one' }, { id: 1, field: '1' }, { id: 2, field: '2' }, { id: 3, field: '3' }] ])