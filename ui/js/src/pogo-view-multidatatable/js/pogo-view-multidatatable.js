/*globals Y, alert */
/**
* The Views Module contains views for displaying data
* @module views
* @namespace Y.Pogo.View
* @requires base,view,datatable,pogo-model-jobslist,tabview,pogo-formatters
*/

/**
* The MultiDatatable View is a special view that constructs multiple datatables in seperate tabs based on given parameters.
* @class MultiDatatable
* @extends Y.View
* @constructor
* @param {object} config Configuration object: See Configuration Attributes
*/
Y.namespace('Pogo.View').MultiDatatable = new Y.Base.create('pogo-view-multidatatable', Y.View, [], {

    setupPaginator: function (node) {
        var pg = new Y.Paginator({
            itemsPerPage: this.get('limit'),
            totalItems: 5,
            page: this.get('offset')
        });
        pg.render(node);
        return pg;
    },

    /**
    * Creates a datatable
    * @method setupDatatable
    * @param {String|Node} container The container which should contain the datatable
    * @param {Array} cols List of columns the datatable should display
    * @param {Object} params An object of key value pairs used for the query
    * @private
    */
    setupDatatable: function (container, cols, params) {
        var ml, dt, o, afterPageChange, pg, dtnode, pgnode;
        //figure out the container
        if (Y.Lang.isString(container)) {
            dtnode = this.get('container').one('.' + container);
            pgnode = this.get('container').one('.' + container + '-pg');
        }
        //add in custom (global) parameters
        o = this.parameterMixIn(params);
        //add in pagination parameters
        o = this.limitMixIn(o);
        //create model list
        ml = new Y.Pogo.Model.JobsList({params: o});
        //create datatable
        dt = new Y.DataTable({
            columns: cols
        });
        dt.render(dtnode);
        dt.set('message', 'Loading...');

        pg = this.setupPaginator(pgnode);
        afterPageChange = function (e) {
            var offset = (pg.get('page') - 1) * pg.get('itemsPerPage'),
                end = offset + pg.get('itemsPerPage');
            dt.set('data', ml._items.slice(offset, end));
        };
        pg.after('pageChange', afterPageChange, this);
        ml.after('load', afterPageChange, this);
        //load data
        ml.load(function (err, o) {
            if (err) {
                alert('Could not load data:\n' + err);
                dt.set('message', 'Error when loading data.');
                pg.set('totalItems', o.meta.count || 5);
            }
        });
    },

    /**
    * Goes through the configuration to build all the necessary datatables
    * @method setupDatatables
    * @private
    */
    setupDatatables: function () {
        var cols = this.get('dtCols'),
            tables = this.get('tables');
        Y.each(tables, function (table) {
            this.setupDatatable(table.className, cols, table.params);
        }, this);
    },

    /**
    * The html template for the view (not including the tabview)
    * @property template
    * @type string
    * @protected
    */
    template: '<h1>{title}</h1>',

    /**
    * Renders the view
    * @method render
    * @return {Object} A reference to this view
    */
    render: function () {
        var activeDT, allDT,
            container = this.get("container"),
            tables = this.get('tables'),
            tabviewCfg = {children: []},
            tabview,
            tabviewContent = '<div class="{className}"></div><div class="{className}-pg"></div>';
        
        //build the tabview configuration
        Y.each(tables, function (table) {
            var tab = {
                    label: table.label,
                    content: Y.Lang.sub(tabviewContent, {className: table.className})
                };
            tabviewCfg.children.push(tab);
        }, this);
        
        //create the tabview
        tabview = new Y.TabView(tabviewCfg);
        
        //setup the view container
        container.addClass('pogo-datatablegroup');
        container.setContent(Y.Lang.sub(this.template, {title: this.get('title')}));
        
        
        //setup datatables after the tabview is ready
        tabview.onceAfter('render', this.setupDatatables, this);
        
        //render the tabview
        tabview.render(container);
        
        return this;
    },

    /**
    * Adds in customizable extra parameters that are added to the table's query
    * @method parameterMixIn
    * @param {Object} o The query parameters thus far
    * @return {Object} The resulting query parameter object
    * @protected
    */
    parameterMixIn: function (o) {
        return o;
    },
    /**
    * Adds in offsets and limits for pagination
    * @method limitMixIn
    * @param {Object} o The query parameters thus far
    * @return {Object} The resulting query parameter object
    * @protected
    */
    limitMixIn: function (o) {
        var limit = this.get('limit'),
            offset = this.get('offset'),
            params = {max: limit};
        if (offset) {
            params.offset = offset;
        }
        return Y.mix(o, params);
    }
}, {
    ATTRS: {
        /**
         * The title of the page
         * @attribute title
         * @type String
         * @default 'Pogo Jobs'
         */
        title: {
            value: 'Pogo Jobs'
        },
        /**
         * The default number of records to show in a page
         * @attribute limit
         * @type number
         * @default 25
         */
        limit: {
            value: 25
        },
        /**
         * The default page (1 based)
         * @attribute offset
         * @type number
         * @default 1
         */
        offset: {
            value: 1
        },
        /**
         * The default columns used by datatables
         * @attribute dtCols
         * @type Array
         */
        dtCols: {
            value: [
                { key: "jobid", label: "Pogo ID", nodeFormatter: Y.Pogo.Formatters.idFormatter},
                { key: "user", label: "User", nodeFormatter: Y.Pogo.Formatters.userFormatter },
                { key: "state", label: "State" },
                { key: "start_time", label: "Start Time", formatter: Y.Pogo.Formatters.timeFormatter },
                { key: "command", label: "Command", nodeFormatter: Y.Pogo.Formatters.commandFormatter },
                { key: "range", label: "Targets", nodeFormatter: Y.Pogo.Formatters.targetFormatter },
                { key: "host_count", label: "Hosts" }
            ]
        },
        /**
         * The default table configuration (active, all)
         * @attribute tables
         * @type Array
         */
        tables: {
            value: [
                {label: 'Active', className: 'dt-active', params: {active: 1}},
                {label: 'All', className: 'dt-all', params: {}}
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
