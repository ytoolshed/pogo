/*globals Y */
/**
* The Job Module is responsible for querying for one or more jobs, and displaying them
* @module job
* @namespace Y.Pogo.Model
* @requires base,model,pogo-env,json-parse,jsonp
*/

/**
* The Job model is responsible for loading a single job, and storing its results.
* The job model may also store one of a set of results for Y.Pogo.Model.JobsList
* @class Job
* @extends Y.Model
* @constructor
* @param {object} config Configuration object: See Configuration Attributes
*/
Y.namespace('Pogo.Model').Job = Y.Base.create('pogo-model-job', Y.Model, [], {
    initializer: function () {
        this.after('logChange', this.calculateFinishTime, this);
        this.after('load', this.calculateFinishTime, this);
        this.calculateFinishTime();
    },
    calculateFinishTime: function () {
        var logs = this.get('log'), finish, duration;
        if (logs && Y.Lang.isArray(logs) && logs.length) {
            finish = logs[logs.length - 1].time;
            duration = finish - this.get('start_time');
            this.set('finish_time', finish, {silent: true});
            this.set('duration', duration, {silent: true});
        }
    },
    /**
    * Generates the URL used to fetch a job
    * @method prepareJobURL
    * @param {String} url The url template to use
    * @param {String} proxy The name of the proxy function to use as a callback
    * @param {String} jobid The jobid to search for
    * @private
    */
    prepareJobURL: function (url, proxy, jobid) {
        return Y.Lang.sub(url, {
            root: Y.Pogo.Env.WSRoot,
            callback: proxy,
            jobid: jobid || this.get('jobid')
        });
    },

    /**
    * Converts a json encoded string into an array for the range value. Called automatically with set('range', val)
    * @method rangeSetter
    * @param {String|Array} val The value to convert/set
    * @private
    */
    rangeSetter: function (val) {
        if (!Y.Lang.isArray(val)) {
            try {
                val = Y.JSON.parse(val);
            } catch (e) {}
        }
        return Y.Lang.isArray(val) ? val : [];
    },

    /**
    * Called automatically for syncing operations (e.g. load()). Only "read" action is implemented
    * @method sync
    * @param {String} action The action to perform ("read", "create", "delete", "update")
    * @param {Object} options The extra values needed for the syncing operation (unused)
    * @param {Function} callback A function to call after the sync operation is complete. Callback signature is callback(errors, results)
    * @private
    */
    sync: function (action, options, callback) {
        if (action === "read") {
            var onSuccess = function (data) {
                    if (data.response && data.response.job && Y.Lang.isObject(data.response.job)) {
                        callback(null, data.response.job);
                    } else {
                        callback('Could not load job');
                    }
                },
                onFailure = function () {
                    callback('Could not load job');
                };
            
            Y.jsonp(Y.Pogo.Env.jobWS, {on: {success: onSuccess, failure: onFailure, timeout: onFailure}, context: this, format: Y.bind(this.prepareJobURL, this), timeout: 2000});
        } else {
            callback('Invalid Action');
        }
    },

    /**
    * Jobs have a custom id attribute 'jobid'
    * @parameter idAttribute
    * @type String
    * @default 'jobid'
    * @private
    */
    idAttribute: 'jobid'
}, {
    ATTRS: {
        /**
         * Primary id for the job
         * @attribute jobid
         * @type String
         * @default ''
         */
        jobid: {
            value: ''
        },
        /**
         * user
         * @attribute user
         * @type String
         * @default ''
         */
        user: {
            value: ''
        },
        /**
         * run as
         * @attribute run_as
         * @type String
         * @default ''
         */
        run_as: {
            value: ''
        },
        /**
         * posthook
         * @attribute posthook
         * @type String
         * @default ''
         */
        posthook: {
            value: ''
        },
        /**
         * Timeout
         * @attribute timeout
         * @type String
         * @default ''
         */
        timeout: {
            value: ''
        },
        /**
         * Prehook
         * @attribute prehook
         * @type String
         * @default ''
         */
        prehook: {
            value: ''
        },
        /**
         * request host
         * @attribute requesthost
         * @type String
         * @default ''
         */
        requesthost: {
            value: ''
        },
        /**
         * invoked as
         * @attribute invoked_as
         * @type String
         * @default ''
         */
        invoked_as: {
            value: ''
        },
        /**
         * Namespace
         * @attribute namespace
         * @type String
         * @default ''
         */
        namespace: {
            value: ''
        },
        /**
         * Client
         * @attribute client
         * @type String
         * @default ''
         */
        client: {
            value: ''
        },
        /**
         * retry
         * @attribute retry
         * @type String
         * @default ''
         */
        retry: {
            value: ''
        },
        /**
         * job_timeout
         * @attribute job_timeout
         * @type String
         * @default ''
         */
        job_timeout: {
            value: ''
        },
        /**
         * state
         * @attribute state
         * @type String
         * @default ''
         */
        state: {
            value: ''
        },
        /**
         * start_time
         * @attribute start_time
         * @type String
         * @default ''
         */
        start_time: {
            value: ''
        },
        /**
         * finish_time
         * @attribute finish_time
         * @type String
         * @default ''
         */
        finish_time: {
            value: ''
        },
        /**
         * log
         * @attribute log
         * @type Array
         * @default []
         */
        log: {
            value: []
        },
        /**
         * command
         * @attribute command
         * @type String
         * @default ''
         */
        command: {
            value: ''
        },
        /**
         * Range. Uses rangeSetter to convert json encoded strings into arrays before setting.
         * @attribute range
         * @type Array
         * @default []
         */
        range: {
            value: [],
            setter: "rangeSetter"
        },
        /**
         * host count
         * @attribute host_count
         * @type String
         * @default ''
         */
        host_count: {
            value: ''
        },
        /**
         * job status
         * @attribute job_status
         * @type String
         * @default ''
         */
        job_status: {
            value: ''
        },
        /**
         * host status (list of hosts for a job)
         * @attribute host_status
         * @type Array
         * @default []
         */
        hosts: {
            value: []
        },
        /**
         * end time
         * @attribute end_time
         * @type String
         * @default ''
         */
        end_time: {
            value: ''
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
