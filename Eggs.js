// Generated by CoffeeScript 1.3.3
(function() {
  var Eggs, Model, escapeRegExp, namedParam, optionalParam, routeStripper, splatParam;

  Eggs = this.Eggs = {};

  Eggs.Model = Model = (function() {

    function Model(attributes, options) {
      var attrs, attrsInitialValidationError, defaults, generatedPropertiesBusses, makeProperty, propertiesBusses, propertyName, propertyNamesBus, setAttributesBus, validAttributesBus,
        _this = this;
      options = _.defaults({}, options, {
        shouldValidate: true
      });
      attrs = attributes || {};
      if (defaults = _.result(this, 'defaults')) {
        attrs = _.defaults({}, attrs, defaults);
      }
      attrsInitialValidationError = options.shouldValidate && (typeof this.validate === "function" ? this.validate(attrs) : void 0);
      validAttributesBus = new Bacon.Bus;
      if (!attrsInitialValidationError) {
        this.attributes = validAttributesBus.toProperty(attrs);
      } else {
        this.attributes = validAttributesBus.toProperty();
      }
      setAttributesBus = new Bacon.Bus;
      this.attributes.set = function(value) {
        return setAttributesBus.push(value);
      };
      propertyNamesBus = new Bacon.Bus;
      this.properties = {};
      propertiesBusses = {};
      makeProperty = function(propertyName) {
        var setPropertyBus;
        if (!_this.properties[propertyName]) {
          _this.properties[propertyName] = _this.attributes.map("." + propertyName);
          setPropertyBus = new Bacon.Bus;
          _this.properties[propertyName].set = function(value) {
            return setPropertyBus.push(value);
          };
          return propertiesBusses[propertyName] = setPropertyBus.toProperty(attrs[propertyName]);
        }
      };
      if (!attrsInitialValidationError) {
        for (propertyName in attrs) {
          makeProperty(propertyName);
        }
      }
      generatedPropertiesBusses = propertyNamesBus.map(function(propertyNames) {
        var _i, _len;
        for (_i = 0, _len = propertyNames.length; _i < _len; _i++) {
          propertyName = propertyNames[_i];
          makeProperty(propertyName);
        }
        return propertiesBusses;
      });
      this.propertyNames = generatedPropertiesBusses.map(function(busses) {
        return _.keys(busses);
      });
      if (!attrsInitialValidationError) {
        this.propertyNames = this.propertyNames.toProperty(_.keys(attrs));
      } else {
        this.propertyNames = this.propertyNames.toProperty();
      }
      Bacon.mergeAll([
        setAttributesBus.map(function(value) {
          return _.defaults({}, value, attrs);
        }), generatedPropertiesBusses.flatMapLatest(Bacon.combineTemplate)
      ]).onValue(function(attrObject) {
        var error;
        if (_.isEqual(attrObject, attrs)) {
          return;
        }
        if (options.shouldValidate && (error = typeof _this.validate === "function" ? _this.validate(attrObject) : void 0)) {
          return validAttributesBus.error({
            error: error,
            attributes: attrObject
          });
        } else {
          if (_.difference(_.keys(attrObject), _.keys(attrs)).length) {
            attrs = attrObject;
            propertyNamesBus.push(_.keys(attrs));
          }
          return validAttributesBus.push(attrs = attrObject);
        }
      });
      propertyNamesBus.push(_.keys(attrs));
      this.initialize.apply(this, arguments);
    }

    Model.prototype.initialize = function() {};

    return Model;

  })();

  Eggs.model = function(extension) {
    var Surrogate, child, parent;
    parent = Model;
    if (extension && _.has(extension, 'constructor')) {
      child = extension.constructor;
    } else {
      child = function() {
        return parent.apply(this, arguments);
      };
    }
    Surrogate = (function() {

      function Surrogate() {
        this.constructor = child;
      }

      return Surrogate;

    })();
    Surrogate.prototype = parent.prototype;
    child.prototype = new Surrogate;
    if (extension) {
      _.extend(child.prototype, extension);
    }
    child.__super__ = parent.prototype;
    return child;
  };

  routeStripper = /^[#\/]|\s+$/g;

  Eggs.currentLocation = (function() {
    var getFragment, getHash, hasHashChange, hasPushState, location, windowLocationStream, _ref;
    location = typeof window !== "undefined" && window !== null ? window.location : void 0;
    hasPushState = location != null ? (_ref = location.history) != null ? _ref.pushState : void 0 : void 0;
    hasHashChange = 'onhashchange' in window;
    getHash = function() {
      var match;
      match = location.href.match(/#(.*)$/);
      if (match) {
        return match[1];
      } else {
        return '';
      }
    };
    getFragment = function(fragment) {
      if (!fragment) {
        if (hasPushState || !hasHashChange) {
          fragment = location.pathname;
        } else {
          fragment = getHash();
        }
      }
      return fragment.replace(routeStripper, '');
    };
    if (hasPushState) {
      windowLocationStream = Bacon.fromEventTarget(window, 'popstate');
    } else if (hasHashChange) {
      windowLocationStream = Bacon.fromEventTarget(window, 'hashchange');
    } else {
      windowLocationStream = Bacon.interval(100);
    }
    return windowLocationStream.map(function() {
      return getFragment();
    }).skipDuplicates().toProperty(getFragment());
  })();

  optionalParam = /\((.*?)\)/g;

  namedParam = /(\(\?)?:\w+/g;

  splatParam = /\*\w+/g;

  escapeRegExp = /[\-{}\[\]+?.,\\\^$|#\s]/g;

  Eggs.route = function(route) {
    if (!_.isRegExp(route)) {
      route = route.replace(escapeRegExp, '\\$&').replace(optionalParam, '(?:$1)?').replace(namedParam, function(match, optional) {
        if (optional) {
          return match;
        } else {
          return '([^\/]+)';
        }
      }).replace(splatParam, '(.*?)');
      route = new RegExp('^' + route + '$');
    }
    return Eggs.currentLocation.filter(function(location) {
      return route.test(location);
    }).map(function(location) {
      return route.exec(location).slice(1);
    });
  };

}).call(this);
