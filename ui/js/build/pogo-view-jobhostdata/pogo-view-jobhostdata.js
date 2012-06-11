YUI.add('pogo-view-jobhostdata', function(Y) {

/*globals Y */
/**
* The Views Module contains views for displaying data
* @module views
* @namespace Y.Pogo.View
* @requires base,view,datatable,pogo-formatters
*/

/**
* Displays host information for a specific job
* @class JobHostData
* @extends Y.View
* @constructor
* @param {object} config Configuration object: See Configuration Attributes
*/
Y.namespace('Pogo.View').JobHostData = new Y.Base.create('pogo-view-jobhostdata', Y.View, [], {
    /**
    * Setup model event
    * @method initializer
    * @private
    */
    initializer: function () {
        var modelList = this.get('modelList');
        modelList.after('load', this.render, this);
        modelList.after('destroy', this.destroy, this);
    },

    /**
    * The html template for the view (not including the datatable)
    * @property template
    * @type string
    * @protected
    */
    template: '<h2>{jobid}\'s Hosts</h2><div class="hostdata"></div>',

    /**
    * Renders the view
    * @method render
    * @return {Object} A reference to this view
    */
    render: function () {
        var dt, div, container = this.get('container'),
            modelList = this.get('modelList');
            
        container.setContent(Y.Lang.sub(this.template, {jobid: this.get('jobid')}));

        div = container.one('.hostdata');
        dt = new Y.DataTable({
            columns: [
                {label: 'Host', key: "host", nodeFormatter: Y.Pogo.Formatters.hostFormatter},
                {label: 'State', key: "state", width: "100px"},
                //{label: "Response Code", key: 'rc'},
                {label: "Time Started", key: 'start_time', formatter: function (o) {
                    var val = Y.Pogo.Formatters.timeFormatter(o);
                    val += " (+" + Math.floor(o.data.start_time - o.data.job_start) + "s)";
                    return val;
                }, width: "195px"},
                {label: "Duration", key: 'duration', formatter: function (o) {
                    return o.value + "s";
                }, width: "75px"},
                {label: "Timeline", key: 'duration', nodeFormatter: function (o) {
                    var per = Math.floor(o.value / o.data.job_duration * 100),
                        per_start = Math.floor((o.data.start_time - o.data.job_start) / o.data.job_duration * 100);
                    o.cell.setContent(Y.Node.create(Y.Lang.sub('<span class="spacer" style="width: {per_start}%">{per_start}</span><span class="duration {status}" style="width: {per}%">{per}</span>', {per_start: per_start, per: per, status: o.data.state})));
                    return false;
                }, width: "250px"}
            ],
            data: modelList
        });
        dt.render(div);
        return this;
    }
}, {
    ATTRS: {
        /**
         * jobid for this page
         * @attribute jobid
         * @type String
         * @default ''
         */
        jobid: {
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


}, '@VERSION@' ,{requires:['base','view']});
