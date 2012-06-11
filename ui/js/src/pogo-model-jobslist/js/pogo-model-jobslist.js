/*globals Y */
/**
* The Job Module is responsible for querying for one or more jobs, and displaying them
* @module job
* @namespace Y.Pogo.Model
* @requires base,modellist,pogo-env,querystring-stringify,jsonp,pogo-model-job
*/

/**
* The Jobs ModelList is responsible for loading multiple jobs based on specific parameters it is given.
* @class JobsList
* @extends Y.ModelList
* @constructor
* @param {object} config Configuration object: See Configuration Attributes
*/
Y.namespace('Pogo.Model').JobsList = Y.Base.create('pogo-model-jobslist', Y.ModelList, [], {
    /**
    * Store results in Y.Pogo.Model.Job model objects
    * @parameter model
    * @type Object
    * @default Y.Pogo.Model.Job
    * @private
    */
    model: Y.Pogo.Model.Job,

    /**
    * Generates the URL used to fetch jobs
    * @method prepareJobsURL
    * @param {String} url The url template to use
    * @param {String} proxy The name of the proxy function to use as a callback
    * @param {String} jobid The jobid to search for
    * @private
    */
    prepareJobsURL: function (url, proxy, params) {
        return Y.Lang.sub(url, {
            root: Y.Pogo.Env.WSRoot,
            callback: proxy,
            params: Y.QueryString.stringify(params || this.get('params'))
        });
    },

    /**
    * Called automatically for syncing operations (e.g. load()). Only "read" action is supported.
    * @method sync
    * @param {String} action The action to perform ("read" is the only action supported by modellist)
    * @param {Object} options The extra values needed for the syncing operation (unused)
    * @param {Function} callback A function to call after the sync operation is complete. Callback signature is callback(errors, results)
    * @private
    */
    sync: function (action, options, callback) {
        if (action === "read") {
            var onSuccess = function (data) {
                    if (data.response && data.response.jobs && Y.Lang.isArray(data.response.jobs)) {
                        callback(null, data.response.jobs);
                    } else {
                        callback('Could not load jobs');
                    }
                },
                onFailure = function () {
                    callback('Could not load jobs');
                };
            
            Y.jsonp(Y.Pogo.Env.jobsWS, {on: {success: onSuccess, failure: onFailure, timeout: onFailure}, context: this, format: Y.bind(this.prepareJobsURL, this), timeout: 2000});
        } else {
            callback('Invalid Action: ' + action);
        }
    }
}, {
    ATTRS: {
        /**
        * A set of key value pairs used to make the query
        * @attribute params
        * @type Object
        * @default {}
        */
        params: {
            value: {}
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
