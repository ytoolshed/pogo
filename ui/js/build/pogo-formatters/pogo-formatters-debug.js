YUI.add('pogo-formatters', function(Y) {

/*globals Y */
/**
* The formatters module is a static collection of data formatters used by datatable
* @module formatters
* @namespace Y.Pogo
* @requires escape,pogo-env,datatype-date
*/

/**
* The formatters class is a static collection of data formatters used by datatable
* @class Formatters
* @static
*/
Y.namespace('Pogo').Formatters = {
    /**
    * Formats the job id with a link to a job page
    * @method idFormatter
    * @param {Object} o The cell and record data
    * @return {boolean} false As required by nodeFormatters
    */
    idFormatter: function (o) {
        o.cell.setContent(Y.Lang.sub('<a href="{root}job/{id}">{id}</a>', {root: Y.Pogo.Env.root, id: o.value}));
        return false;
    },
    
    /**
    * Formats the command column
    * @method columnFormatter
    * @param {Object} o The cell and record data
    * @return {boolean} false As required by nodeFormatters
    */
    commandFormatter: function (o) {
        var value = Y.Pogo.Formatters.truncateText(o.value);
        o.cell.setContent(Y.Lang.sub('<span title="{command}">{command_trunc}</span>', {command: Y.Escape.html(o.value), command_trunc: value}));
        return false;
    },
    
    /**
    * Formats a time column
    * @method timeFormatter
    * @param {Object} o The cell and record data
    * @return {String} The formatted date
    */
    timeFormatter: function (o) {
        var date = Y.DataType.Date.format(new Date(o.value * 1000), {format: "%x %X"});
        return date;
    },
    
    /**
    * Formats user column with link to user page
    * @method userFormatter
    * @param {Object} o The cell and record data
    * @return {boolean} false As required by nodeFormatters
    */
    userFormatter: function (o) {
        o.cell.setContent(Y.Lang.sub('<a href="{root}user/{username}">{username}</a>', {root: Y.Pogo.Env.root, username: o.value}));
        return false;
    },
    
    /**
    * Formats target (range) column
    * @method targetFormatter
    * @param {Object} o The cell and record data
    * @return {boolean} false As required by nodeFormatters
    */
    targetFormatter: function (o) {
        var targets = o.value.join(', ');
        o.cell.setContent(Y.Lang.sub('<span title="{targets}">{targets_trunc}</span>', {targets: Y.Escape.html(targets), targets_trunc: Y.Pogo.Formatters.truncateText(targets)}));
        return false;
    },

    /**
    * Formats host column with link to host page
    * @method hostFormatter
    * @param {Object} o The cell and record data
    * @return {boolean} false As required by nodeFormatters
    */
    hostFormatter: function (o) {
        o.cell.setContent(Y.Lang.sub('<a href="{root}job/{jobid}/{hostname}">{hostname}</a>', {root: Y.Pogo.Env.root, jobid: o.data.jobid, hostname: o.value}));
        return false;
    },

    /**
    * Truncates text to desired length
    * @method truncateText
    * @param {String} text The text to truncate
    * @param {number} length The length the text should be
    * @return {String} The truncated text
    */
    truncateText: function (text, length) {
        length = length || 20;
        return text.length > length - 3 ? Y.Escape.html(text.substring(0, length) + '...') : Y.Escape.html(text);
    }
};

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


}, '@VERSION@' ,{requires:['escape','pogo-env','datatype-date']});
