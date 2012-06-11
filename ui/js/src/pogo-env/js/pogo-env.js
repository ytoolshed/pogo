/*globals Y,window */
/**
* The Env module contains static references to global constants
* @module Env
* @namespace Y.Pogo
*/

/**
* The Env class contains static references to global constants
* @class Env
* @static
*/
Y.namespace('Pogo').Env = {
    /**
    * Root of the webserver
    * @parameter root
    * @type String
    * @default '/'
    * @static
    */
    root: '/pogo/',
    
    /**
    * Root URL for the API calls
    * @parameter WSRoot
    * @type String
    * @static
    */
    WSRoot: "http://" + window.location.hostname + ":7657/v1",

    /**
    * Template for the jobs WS call
    * @parameter jobsWS
    * @type String
    * @static
    */
    jobsWS: "{root}/jobs?{params}&cb={callback}",

    /**
    * Template for the job WS call
    * @parameter jobWS
    * @type String
    * @static
    */
    jobWS: "{root}/jobs/{jobid}?cb={callback}",

    /**
    * Template for the job log WS call
    * @parameter jobLogWS
    * @type String
    * @static
    */
    jobLogWS: "{root}/jobs/{jobid}/log?cb={callback}",

    /**
    * Template for the job hosts list WS call
    * @parameter jobHostsWS
    * @type String
    * @static
    */
    jobHostsWS: "{root}/jobs/{jobid}/hosts?cb={callback}",
    
    /**
    * Template for the job host WS call
    * @parameter jobHostWS
    * @type String
    * @static
    */
    jobHostWS: "{root}/jobs/{jobid}/hosts/{hostname}?cb={callback}"
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
