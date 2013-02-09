# Eggs.js

Eggs.js want to be a Reactive Javascript Web App Framework based on [Bacon.js](https://github.com/raimohanska/bacon.js).

## Motivation

[Bacon.js makes functional reactive programming sizzle](http://blog.flowdock.com/2013/01/22/functional-reactive-programming-with-bacon-js/). To use it to create web applications however, you still need a structure like the one provided by [Backbone.js](https://github.com/documentcloud/backbone/). Backbone.js and other similar frameworks are event-based and are an akward fit to Bacon.js FRP capabilities.

Eggs.js could be used to provide the structure needed to easily assemble web applications based on REST services. A collection of tools and best practices to do so, would make a redistributable framework that would be as tasty as bacon with eggs.

## Current status

:construction: Eggs.js is still in development and is not usable yet. :construction:

Version `0.0.1`: Eggs.js is just taking form.

## Roadmap

Here is an indication of how Eggs.js development should proceeed. Holes in versions are there to allow for further refinements.

- Version `0.0.2` will have `Model`, `Collection` and `Router` with relative unit tests inspired by [Backbone.js](https://github.com/documentcloud/backbone/). The goal is to be able to start playing around with those components to figure out the best API and how to structure the `View` class.
- Version `0.0.4` will have a refined API for Model, Collection and Router.
- Version `0.0.7` will have an initial `View` implementation.
- Version `0.1` will be usable in place of Backbone.js.
- Version `0.2` will have a cleaned API ready to move to further development.
- Version `1.0` will be stable and have a finalized API and will incorporate higher order components like `Application`, `Layout` to be usable in commercial settings.

## How to build

Get [CoffeeScript](http://coffeescript.org/) installed and compile all `.coffee` files to `.js` with:

`coffee -c */*.coffee`

To run unit tests open `test/index.html`.

## Vision and Guidelines

To start off, Eggs.js will have Backbone.js as reference point. However, it is quite common when developing a web app to use an additional framework over Backbone.js (see [Marionette](http://marionettejs.com/), [Chaplin](http://chaplinjs.org/)) to gain additional structure. Eggs.js should provide all the neccessary structure to be used as one of those higher-level framework if needed.

**Guidelines and code examples to come**

## Contribute

If you like the idea and want to comment, suggest or code; please do open new issues. The project is in a very early stage so any feedback is welcome as of now.

## License

Eggs.js is distributed under MIT license.
