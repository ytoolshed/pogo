YUI.add('pogo-model-host', function(Y) {

/*globals Y */
/**
* The Host Module is responsible for storing info for one or more hosts, and displaying them
* @module host
* @namespace Y.Pogo.Model
* @requires base,model
*/

/**
* The Host model is a convenient storage mechanism for host data
* @class Host
* @extends Y.Model
* @constructor
* @param {object} config Configuration object: See Configuration Attributes
*/
Y.namespace('Pogo.Model').Host = Y.Base.create('pogo-model-host', Y.Model, [], {}, {
    ATTRS: {
        /**
        * hostname
        * @attribute host
        * @type string
        * @default ''
        */
        host: {
            value: ''
        },
        /**
        * state
        * @attribute state
        * @type string
        * @default ''
        */
        state: {
            value: ''
        },
        /**
        * response code
        * @attribute rc
        * @type string
        * @default ''
        */
        rc: {
            value: ''
        },
        /**
        * start time
        * @attribute start_time
        * @type string
        * @default ''
        */
        start_time: {
            value: ''
        },
        /**
        * finish time
        * @attribute finish_time
        * @type string
        * @default ''
        */
        finish_time: {
            value: ''
        },
        /**
        * duration
        * @attribute duration
        * @type string
        * @default ''
        */
        duration: {
            value: ''
        },
        /**
        * jobid associated with this host process
        * @attribute jobid
        * @type string
        * @default ''
        */
        jobid: {
            value: ''
        },
        job_start: {
            value: 0
        },
        job_finish: {
            value: 0
        },
        job_duration: {
            value: 0
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


}, '@VERSION@' ,{requires:['base','model']});
