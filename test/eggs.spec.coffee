describe "Eggs environment", () ->
	it "should have Eggs", () ->
		expect(Eggs).toBeDefined()

	it "should have a `pluck` method for Bacon.Observable", ->
		expectStreamEvents(
			->
				b = new Bacon.Bus
				p = b.pluck('one')
				soon ->
					b.push([ { two: 2, one: 1 }, {}, { one: 'one', three: 3} ])
					b.push('not an object')
					b.end()
				p
			[ [1, undefined, 'one'] ])

	it "should have a `pick` method for Bacon.Observable", ->
		expectStreamEvents(
			->
				b = new Bacon.Bus
				p = b.pick('one', 'two')
				soon ->
					b.push({ two: 2, one: 1 })
					b.push('not an object')
					b.push({ one: 'one', three: 3})
					b.end()
				p
			[ { one: 1, two: 2 }, { one: 'one' } ])

	it "should have a `keys` method for Bacon.Observable", ->
		expectStreamEvents(
			->
				b = new Bacon.Bus
				p = b.keys()
				soon ->
					b.push({ two: 2, one: 1 })
					b.push('not an object')
					b.push({ one: 'one', three: 3})
					b.end()
				p
			[ ['two', 'one'], ['one', 'three'] ])
