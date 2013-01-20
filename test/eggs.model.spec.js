// Generated by CoffeeScript 1.3.3
(function() {
  var __hasProp = {}.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

  describe("Eggs.Model", function() {
    it("should exists", function() {
      return expect(Eggs.Model).toBeDefined();
    });
    it("should be usable as class extension", function() {
      var TestModel, testModel;
      TestModel = (function(_super) {

        __extends(TestModel, _super);

        function TestModel() {
          return TestModel.__super__.constructor.apply(this, arguments);
        }

        return TestModel;

      })(Eggs.Model);
      testModel = new TestModel;
      return expect(testModel).not.toBeNull();
    });
    it("should initialize", function() {
      var TestModel, testModel;
      TestModel = (function(_super) {

        __extends(TestModel, _super);

        function TestModel() {
          return TestModel.__super__.constructor.apply(this, arguments);
        }

        TestModel.prototype.initialize = function() {
          return this.one = 1;
        };

        return TestModel;

      })(Eggs.Model);
      testModel = new TestModel;
      return expect(testModel.one).toEqual(1);
    });
    it("should initialize with attributes and options", function() {
      var TestModel, testModel;
      TestModel = (function(_super) {

        __extends(TestModel, _super);

        function TestModel() {
          return TestModel.__super__.constructor.apply(this, arguments);
        }

        TestModel.prototype.initialize = function(attributes, options) {
          return this.one = options.one;
        };

        return TestModel;

      })(Eggs.Model);
      testModel = new TestModel({}, {
        one: 1
      });
      return expect(testModel.one).toEqual(1);
    });
    describe("without attributes", function() {
      var TestModel, testModel;
      TestModel = (function(_super) {

        __extends(TestModel, _super);

        function TestModel() {
          return TestModel.__super__.constructor.apply(this, arguments);
        }

        return TestModel;

      })(Eggs.Model);
      testModel = null;
      beforeEach(function() {
        return testModel = new TestModel;
      });
      it("should define `attributes` Bacon.Property", function() {
        return expect(testModel.attributes instanceof Bacon.Property).toBeTruthy();
      });
      it("should push an empty object form `attributes`", function() {
        return expectPropertyEvents(function() {
          return testModel.attributes.take(1);
        }, [{}]);
      });
      it("should have a Bacon.Property as `attributeNames`", function() {
        return expect(testModel.attributeNames instanceof Bacon.Property).toBeTruthy();
      });
      it("should add new attributes when setting `attributes`", function() {
        return expectPropertyEvents(function() {
          var p;
          p = testModel.attributes.take(2);
          soon(function() {
            return testModel.attributes.set({
              one: 1
            });
          });
          return p;
        }, [
          {}, {
            one: 1
          }
        ]);
      });
      return it("should add a new property to `attributeNames` when setting `attributes`", function() {
        return expectPropertyEvents(function() {
          var p;
          p = testModel.attributeNames.take(2);
          soon(function() {
            return testModel.attributes.set({
              one: 1
            });
          });
          return p;
        }, [[], ['one']]);
      });
    });
    describe("with default attributes", function() {
      var TestModel, testModel;
      TestModel = (function(_super) {

        __extends(TestModel, _super);

        function TestModel() {
          return TestModel.__super__.constructor.apply(this, arguments);
        }

        TestModel.prototype.defaults = {
          one: 'one',
          two: 'two'
        };

        return TestModel;

      })(Eggs.Model);
      testModel = null;
      beforeEach(function() {
        return testModel = new TestModel({
          two: 2
        });
      });
      it("should have Bacon.Property as for each attribute in `attribute`", function() {
        expect(testModel.attribute.one instanceof Bacon.Property).toBeTruthy();
        return expect(testModel.attribute.two instanceof Bacon.Property).toBeTruthy();
      });
      it("should push attributes", function() {
        return expectPropertyEvents(function() {
          return testModel.attributes.take(1);
        }, [
          {
            one: 'one',
            two: 2
          }
        ]);
      });
      it("should push single attributes", function() {
        expectPropertyEvents(function() {
          return testModel.attribute.one.take(1);
        }, ['one']);
        return expectPropertyEvents(function() {
          return testModel.attribute.two.take(1);
        }, [2]);
      });
      it("should have `set` method for attributes", function() {
        return expect(testModel.attributes.set).toBeDefined();
      });
      it("shuld have `set` method for single attributes", function() {
        expect(testModel.attribute.one.set).toBeDefined();
        return expect(testModel.attribute.two.set).toBeDefined();
      });
      it("should push attributes on attributes update", function() {
        return expectPropertyEvents(function() {
          var p;
          p = testModel.attributes.take(2);
          soon(function() {
            return testModel.attributes.set({
              one: 1
            });
          });
          return p;
        }, [
          {
            one: 'one',
            two: 2
          }, {
            one: 1,
            two: 2
          }
        ]);
      });
      it("should push single attributes when updated", function() {
        return expectPropertyEvents(function() {
          var p;
          p = testModel.attribute.one.take(2);
          soon(function() {
            return testModel.attribute.one.set(1);
          });
          return p;
        }, ['one', 1]);
      });
      it("should push attributes on single attributes update", function() {
        return expectPropertyEvents(function() {
          var p;
          p = testModel.attributes.take(2);
          soon(function() {
            return testModel.attribute.one.set(1);
          });
          return p;
        }, [
          {
            one: 'one',
            two: 2
          }, {
            one: 1,
            two: 2
          }
        ]);
      });
      it("should NOT push attributes if nothing changed", function() {
        return expectPropertyEvents(function() {
          var p;
          p = testModel.attributes.take(2);
          soon(function() {
            testModel.attributes.set({
              two: 2
            });
            return testModel.attributes.set({
              one: 1
            });
          });
          return p;
        }, [
          {
            one: 'one',
            two: 2
          }, {
            one: 1,
            two: 2
          }
        ]);
      });
      it("should NOT push a single attribute if nothing changed", function() {
        return expectPropertyEvents(function() {
          var p;
          p = testModel.attribute.one.take(2);
          soon(function() {
            testModel.attribute.one.set('one');
            return testModel.attribute.one.set(1);
          });
          return p;
        }, ['one', 1]);
      });
      it("should have correct `attributeNames` names", function() {
        return expectPropertyEvents(function() {
          return testModel.attributeNames.take(1).map(function(v) {
            return v.sort();
          });
        }, [['one', 'two']]);
      });
      return it("should add a new attribute", function() {
        return expectPropertyEvents(function() {
          var p;
          p = testModel.attributeNames.take(2).map(function(v) {
            return v.sort();
          });
          soon(function() {
            return testModel.attributes.set({
              three: 3
            });
          });
          return p;
        }, [['one', 'two'], ['one', 'three', 'two']]);
      });
    });
    describe("with validation", function() {
      var TestModel, testModel;
      TestModel = (function(_super) {

        __extends(TestModel, _super);

        function TestModel() {
          return TestModel.__super__.constructor.apply(this, arguments);
        }

        TestModel.prototype.defaults = {
          one: 'one'
        };

        TestModel.prototype.validate = function(attr) {
          if (!_.isString(attr.one)) {
            return "invalid";
          }
        };

        return TestModel;

      })(Eggs.Model);
      testModel = null;
      beforeEach(function() {
        return testModel = new TestModel;
      });
      it("should push initial attributes", function() {
        return expectPropertyEvents(function() {
          return testModel.attributes.take(1);
        }, [
          {
            one: 'one'
          }
        ]);
      });
      it("should push initial single attributes", function() {
        return expectPropertyEvents(function() {
          return testModel.attribute.one.take(1);
        }, ['one']);
      });
      it("should push an error on validation fail", function() {
        testModel.attributes.onError(function(err) {
          return expect(err).toEqual({
            error: 'invalid',
            attributes: {
              one: 1
            }
          });
        });
        return testModel.attributes.set({
          one: 1
        });
      });
      return it("should not validate if `shouldValidate` option is false", function() {
        testModel = new TestModel({
          one: 1
        }, {
          shouldValidate: false
        });
        return expectPropertyEvents(function() {
          var p;
          p = testModel.attributes.take(2);
          soon(function() {
            return testModel.attributes.set({
              one: 2
            });
          });
          return p;
        }, [
          {
            one: 1
          }, {
            one: 2
          }
        ]);
      });
    });
    return describe("when invalid", function() {
      var TestModel, testModel;
      TestModel = (function(_super) {

        __extends(TestModel, _super);

        function TestModel() {
          return TestModel.__super__.constructor.apply(this, arguments);
        }

        TestModel.prototype.defaults = {
          one: 'one'
        };

        TestModel.prototype.validate = function(attr) {
          if (!_.isString(attr.one)) {
            return "invalid";
          }
        };

        return TestModel;

      })(Eggs.Model);
      testModel = null;
      beforeEach(function() {
        return testModel = new TestModel({
          one: 1
        });
      });
      it("should NOT push initial attributes if invalid", function() {
        return expectPropertyEvents(function() {
          var p;
          p = testModel.attributes.take(1);
          soon(function() {
            return testModel.attributes.set({
              one: 'one'
            });
          });
          return p;
        }, [
          {
            one: 'one'
          }
        ]);
      });
      it("should NOT push an initial single attributes if invalid", function() {
        return expectPropertyEvents(function() {
          var p;
          p = testModel.attribute.one.take(1);
          soon(function() {
            return testModel.attribute.one.set('one');
          });
          return p;
        }, ['one']);
      });
      return it("should NOT push initial attributeNames", function() {
        return expectPropertyEvents(function() {
          var p;
          p = testModel.attributeNames.take(1).map(function(v) {
            return v.sort();
          });
          soon(function() {
            return testModel.attributes.set({
              one: 'valid',
              two: 2
            });
          });
          return p;
        }, [['one', 'two']]);
      });
    });
  });

}).call(this);
