YUI.add('pogo-app', function(Y) {

/*globals Y */
/**
* The Controller for the entire application
* @module app
* @namespace Y.Pogo
* @requires base,app,pogo-view-dashboard,pogo-view-user,pogo-view-job,pogo-view-host,pogo-model-job
*/

/**
* The Pogo App is the main controller for the entire web app
* @class App
* @extends Y.App
* @constructor
* @param {object} config Configuration object: See Configuration Attributes
*/
Y.namespace('Pogo').App = new Y.Base.create('pogo-app', Y.App, [], {
    /**
    * Defines the views used in this application
    * @property views
    * @type Object
    */
    views: {
        home: {type: "Pogo.View.Dashboard"},
        user: {type: "Pogo.View.User"},
        job: {type: "Pogo.View.Job"},
        host: {type: "Pogo.View.Host"}
    },

    /**
    * Handles homepage requests
    * @method handleHome
    * @param {Object} req The request object
    * @private
    */
    handleHome: function (req) {
        Y.one('title').set('text', 'Pogo - Home');
        this.showView('home');
    },

    /**
    * Handles user page requests
    * @method handleUser
    * @param {Object} req The request object
    * @private
    */
    handleUser: function (req) {
        var name = req.params.name;
        Y.one('title').set('text', 'Pogo - ' + name + "'s Jobs");
        this.showView('user', {user: name});
    },

    /**
    * Handles job page requests
    * @method handleJob
    * @param {Object} req The request object
    * @private
    */
    handleJob: function (req) {
        var jobid = req.params.jobid,
            model = new Y.Pogo.Model.Job({jobid: jobid});
        model.after('load', function () {
            Y.one('title').set('text', 'Pogo - Job ' + jobid);
            this.showView('job', {model: model});
        }, this);
        model.load();
    },

    /**
    * Handles host page requests
    * @method handleHost
    * @param {Object} req The request object
    * @private
    */
    handleHost: function (req) {
        var jobid = req.params.jobid,
            hostname = req.params.hostname,
            model = new Y.Pogo.Model.Job({jobid: jobid});
        model.after('load', function () {
            Y.one('title').set('text', 'Pogo - Job ' + jobid + ' Host: ' + hostname);
            this.showView('host', {model: model, host: hostname});
        }, this);
        model.load();
    },

    /**
    * Handles page requests we haven't explicitly defined
    * @method handleInvalidPage
    * @param {Object} req The request object
    * @private
    */
    handleInvalidPage: function (req) {
        Y.one('title').set('text', 'Pogo - Unknown request: ' + req.path);
        this.showView('home');
    },
    render: function () {
        Y.one('.oss-tools-content a').set('href', Y.Pogo.Env.root);
        return this;
    }
}, {
    ATTRS: {
        /**
         * Setup app to work with/without server (ideally this is true, e.g. w/ server support)
         * @attribute serverRouting
         * @type boolean
         * @default false
         */
        serverRouting: {
            value: true
        },
        /**
         * Where do the views go?
         * @attribute viewContainer
         * @type String
         * @default '#application-content'
         */
        viewContainer: {
            value: '#application-content'
        },
        /**
         * What view to display based on path?
         * @attribute routes
         * @type Array
         */
        routes: {
            value: [
                {path: Y.Pogo.Env.root, callback: 'handleHome'},
                {path: Y.Pogo.Env.root + 'user/:name', callback: 'handleUser'},
                {path: Y.Pogo.Env.root + 'job/:jobid', callback: 'handleJob'},
                {path: Y.Pogo.Env.root + 'job/:jobid/:hostname', callback: 'handleHost'},
                {path: '*', callback: 'handleInvalidPage'}
            ]
        }
    }
});

/**
 * Copyright (c) 2010-2012 Yahoo! Inc. All rights reserved.
 *
 *     Licensed under the Apache License, Version 2.0 (the "License"); you
 * may not use this file except in compliance with the License.  You may
 * obtain a copy of the License at
 *
 *  http://www.apache.org/licenses/LICENSE-2.0
 *
 *    Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * imitations under the License.
 */


}, '@VERSION@' ,{requires:['base','app','pogo-view-dashboard','pogo-view-user','pogo-view-job','pogo-view-host','pogo-model-job']});
