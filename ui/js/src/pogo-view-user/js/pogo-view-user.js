/*globals Y */
/**
* The Views Module contains views for displaying data
* @module views
* @namespace Y.Pogo.View
* @requires base,pogo-view-multidatatable
*/

/**
* The User is slightly different from the default view as it is resricted to a specific user's jobs, and user is not displayed in the tables.
* @class User
* @extends Y.View
* @constructor
* @param {object} config Configuration object: See Configuration Attributes
*/
Y.namespace('Pogo.View').User = new Y.Base.create('pogo-view-user', Y.Pogo.View.MultiDatatable, [], {
    /**
    * Adds in user for each datatable query
    * @method parameterMixIn
    * @param {Object} o The query parameters thus far
    * @return {Object} The resulting query parameter object
    * @private
    */
    parameterMixIn: function (o) {
        o.user = this.get('user');
        return o;
    },

    /**
    * Getter for the title paramter. Brings in the User's name
    * @method getTitle
    * @return {String} The page title
    * @private
    */
    getTitle: function () {
        return this.get('user') + "'s Jobs";
    }
}, {
    ATTRS: {
        /**
         * The user's name (for this page)
         * @attribute user
         * @type String
         * @default ''
         */
        user: {
            value: ''
        },
        /**
         * The page title (uses getTitle getter)
         * @attribute title
         * @type String
         * @default "{User}'s Jobs"
         */
        title: {
            getter: 'getTitle'
        },
        /**
         * Removed the user column from default list
         * @attribute dtCols
         * @type Array
         */
        dtCols: {
            value: [
                { key: "jobid", label: "Pogo ID", nodeFormatter: Y.Pogo.Formatters.idFormatter},
                { key: "state", label: "State" },
                { key: "start_time", label: "Start Time", formatter: Y.Pogo.Formatters.timeFormatter },
                { key: "command", label: "Command", nodeFormatter: Y.Pogo.Formatters.commandFormatter },
                { key: "range", label: "Targets", nodeFormatter: Y.Pogo.Formatters.targetFormatter },
                { key: "host_count", label: "Hosts" }
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
